# frozen_string_literal: true

require "securerandom"
require "active_model"
require "aws-record"
require "orm_adapter"
require "devise/orm/dynamodb/uniqueness_validator"

module Devise
  module Orm
    # Support for models stored in DynamoDB with the aws-record gem.
    #
    #   class User
    #     include Devise::Orm::AwsRecordSupport
    #
    #     string_attr :email
    #     ...
    #     devise :database_authenticatable, :recoverable
    #   end
    #
    # Including the concern gives the model `Aws::Record` (attributes, keys,
    # GSIs), the ActiveModel pieces Devise relies on (validations, callbacks,
    # naming, conversion), an OrmAdapter, and the uniqueness validator.
    #
    # aws-record has no notion of ActiveModel callbacks or validations, so
    # `save` is re-implemented here around the aws-record persistence call.
    module AwsRecordSupport
      # Formats Time attributes with microsecond precision, like ActiveRecord
      # does for datetime columns. The aws-record default is whole seconds,
      # which breaks Rememberable's timestamp comparisons.
      module MicrosecondTimeFormatter
        def self.format(time)
          time.getutc.iso8601(6)
        end
      end

      def self.model?(klass)
        klass.is_a?(Class) && klass.include?(self)
      end

      def self.included(base)
        base.include Aws::Record
        base.include ActiveModel::Validations
        base.include ActiveModel::Validations::Callbacks
        base.include ActiveModel::Conversion
        base.include ActiveModel::Serializers::JSON
        base.include Serialization
        base.include DirtyTracking
        base.prepend Persistence

        base.extend ActiveModel::Callbacks
        base.define_model_callbacks :save, :create, :update, :destroy
        base.extend ClassMethods
        base.extend Devise::Models
        base.extend ::OrmAdapter::ToAdapter
        base.extend Devise::Orm::Dynamodb::UniquenessValidation

        base.extend Inheritance

        base.string_attr :id, hash_key: true
      end

      # Subclasses (e.g. `class Admin2 < User`) inherit attributes and keys
      # from aws-record only when they include Aws::Record themselves, so
      # re-include it for every subclass.
      module Inheritance
        def inherited(subclass)
          super
          subclass.include Aws::Record
          subclass.include Devise::Orm::AwsRecordSupport::DirtyTracking
          subclass.include Devise::Orm::AwsRecordSupport::Serialization
          subclass.prepend Devise::Orm::AwsRecordSupport::Persistence
          subclass.extend Devise::Models
          subclass.extend ::OrmAdapter::ToAdapter
          subclass.extend Devise::Orm::Dynamodb::UniquenessValidation
        end
      end

      # Used by Devise::Orm.dynamodb? and by Devise::Orm.included to pick the
      # dirty-tracking methods.
      class OrmAdapter < ::OrmAdapter::Base
        # @see OrmAdapter::Base#column_names
        def column_names
          klass.attribute_names.map(&:to_s)
        end

        # @see OrmAdapter::Base#get!
        def get!(id)
          get(id) || raise(Aws::Record::Errors::NotFound, "No #{klass.name} found with id #{id.inspect}")
        end

        # @see OrmAdapter::Base#get
        def get(id)
          key = wrap_key(id)
          return nil if key.nil? || key == ""

          klass.find(klass.hash_key => key)
        end

        # @see OrmAdapter::Base#find_first
        def find_first(options = {})
          find_all(options.merge(limit: 1)).first
        end

        # @see OrmAdapter::Base#find_all
        def find_all(options = {})
          conditions, order, limit, offset = extract_conditions!(options)
          # Devise passes HashWithIndifferentAccess, whose keys stay Strings
          # through transform_keys; aws-record attribute lookups need Symbols.
          conditions = conditions.to_h.to_h { |key, value| [key.to_sym, value] }

          records = []
          each_candidate(conditions) do |record|
            records << record if matches?(record, conditions)
          end

          records = sort_records(records, order) unless order.empty?
          records = records.drop(offset) if offset
          records = records.first(limit) if limit
          records
        end

        # @see OrmAdapter::Base#create!
        def create!(attributes = {})
          klass.create!(attributes)
        end

        # @see OrmAdapter::Base#destroy
        def destroy(object)
          object.destroy if valid_object?(object)
        end

        private

        # Yields every stored record that could match the conditions, using
        # the cheapest access path: a get by table key, a Query on a GSI whose
        # hash key is one of the conditions, or a Scan with a filter.
        def each_candidate(conditions, &block)
          hash_key = klass.hash_key
          if conditions.key?(hash_key) && !conditions[hash_key].nil?
            record = get(conditions[hash_key])
            yield record if record
          elsif (index_name, index_attr = usable_index(conditions))
            klass.query(
              index_name: index_name.to_s,
              key_condition_expression: "#k = :v",
              expression_attribute_names: { "#k" => klass.attributes.storage_name_for(index_attr) },
              expression_attribute_values: { ":v" => serialize(index_attr, conditions[index_attr]) }
            ).each(&block)
          else
            klass.scan(scan_options(conditions)).each(&block)
          end
        end

        # A GSI can only answer an equality on a non-nil value: records with an
        # absent (nil) attribute are not indexed.
        def usable_index(conditions)
          klass.global_secondary_indexes.each do |name, opts|
            attr = opts[:hash_key]&.to_sym
            next unless attr && conditions.key?(attr) && !conditions[attr].nil?

            return [name, attr]
          end
          nil
        end

        def scan_options(conditions)
          return {} if conditions.empty?

          names = {}
          values = {}
          clauses = conditions.map.with_index do |(attr, value), i|
            name_token = "#f#{i}"
            names[name_token] = klass.attributes.storage_name_for(attr)
            if value.nil?
              "attribute_not_exists(#{name_token})"
            else
              value_token = ":f#{i}"
              values[value_token] = serialize(attr, value)
              "#{name_token} = #{value_token}"
            end
          end

          options = { filter_expression: clauses.join(" AND "), expression_attribute_names: names }
          options[:expression_attribute_values] = values unless values.empty?
          options
        end

        # Conditions that were not used by the access path are checked here.
        # nil matches an absent attribute, as it does in ActiveRecord.
        def matches?(record, conditions)
          conditions.all? do |attr, value|
            current = record.public_send(attr)
            value.nil? ? current.nil? : current == value
          end
        end

        def sort_records(records, order)
          records.sort do |a, b|
            order.lazy.map do |attr, direction|
              comparison = compare_values(a.public_send(attr), b.public_send(attr))
              direction == :desc ? -comparison : comparison
            end.find(&:nonzero?) || 0
          end
        end

        def compare_values(a, b)
          return 0 if a.nil? && b.nil?
          return -1 if a.nil?
          return 1 if b.nil?

          a <=> b
        end

        def serialize(attr, value)
          klass.attributes.attribute_for(attr.to_sym).serialize(value)
        end
      end

      # ActiveModel::Serialization reads `attributes` (a Hash of name => value).
      # Every declared attribute is included, nil or not, as in ActiveRecord.
      module Serialization
        def attributes
          self.class.attributes.attributes.keys.to_h { |name| [name.to_s, public_send(name)] }
        end

        def attribute_names_for_serialization
          attributes.keys
        end
      end

      # Dirty tracking that Devise reads through the primitives below
      # (see Devise::Orm::DirtyTrackingDynamodbMethods).
      #
      # "Pending" changes are the ones aws-record would write on the next save.
      # "Saved" changes are the ones written by the last save and are recorded
      # before after_create/after_update run, so Devise sees them there too.
      module DirtyTracking
        def devise_attribute_will_save_change?(attribute)
          attribute_dirty?(attribute.to_sym)
        end

        def devise_attribute_in_database(attribute)
          attribute_was(attribute.to_sym)
        end

        def devise_attribute_saved_change?(attribute)
          (@devise_saved_changes || {}).key?(attribute.to_sym)
        end

        def devise_attribute_before_last_save(attribute)
          # Like ActiveRecord: unchanged by the last save -> the current value.
          (@devise_saved_changes || {}).fetch(attribute.to_sym) { [public_send(attribute)] }.first
        end

        def devise_attribute_force_change!(attribute)
          attribute_dirty!(attribute.to_sym)
        end

        # Records are equal when they are the same persisted item, as in
        # ActiveRecord (aws-record itself compares object identity).
        def ==(other)
          super || (other.instance_of?(self.class) && !id.nil? && persisted? && other.persisted? && id == other.id)
        end
        alias eql? ==

        def hash
          id.nil? ? super : [self.class, id].hash
        end

        # ActiveRecord/Mongoid-style attribute predicates (`unconfirmed_email?`),
        # which Devise's views and mailers call via `try`.
        def respond_to_missing?(name, include_private = false)
          devise_predicate_attribute(name) ? true : super
        end

        def method_missing(name, *args, &block)
          attribute = devise_predicate_attribute(name)
          return super unless attribute && args.empty?

          public_send(attribute).present?
        end

        # ActiveModel-style names for the pending and saved changes.
        def changed?
          dirty?
        end

        def changes
          dirty.to_h { |name| [name.to_s, [attribute_was(name), public_send(name)]] }
        end

        def saved_changes
          (@devise_saved_changes || {}).transform_keys(&:to_s)
        end

        private

        def devise_predicate_attribute(name)
          name = name.to_s
          return unless name.end_with?("?")

          attribute = name.delete_suffix("?").to_sym
          attribute if self.class.attributes.present?(attribute)
        end
      end

      # Prepended so that `save` wraps aws-record's own save.
      module Persistence
        def save(options = {})
          opts = options.dup
          validate = opts.delete(:validate) != false
          return false if validate && !valid?

          self.id = SecureRandom.uuid if new_record? && id.blank?
          clear_blank_index_keys
          touch_timestamps

          saved = false
          run_callbacks(:save) do
            run_callbacks(new_record? ? :create : :update) do
              pending = dirty.to_h { |name| [name, [attribute_was(name), public_send(name)]] }
              saved = super(opts)
              @devise_saved_changes = pending
            end
          end
          saved
        end

        def update_attribute(name, value)
          public_send("#{name}=", value)
          save(validate: false)
        end

        def destroy
          run_callbacks(:destroy) do
            delete!
            self
          end
        end

        def reload
          reload!
        end

        # Devise reads and writes attributes by name, e.g. self[:email].
        def [](name)
          public_send(name) if self.class.attributes.present?(name.to_sym)
        end

        def []=(name, value)
          public_send("#{name}=", value)
        end

        private

        # aws-record calls #valid? itself when it responds to it. Validation has
        # already run in #save, so it must not run a second time.
        def _invalid_record?(_opts)
          false
        end

        # Maintains created_at / updated_at when the model declares them, as
        # ActiveRecord and Dynamoid do. Only touched when something changed.
        def touch_timestamps
          return unless new_record? || dirty?

          now = Time.now.utc
          attrs = self.class.attributes
          self.created_at ||= now if attrs.present?(:created_at)
          self.updated_at = now if attrs.present?(:updated_at)
        end

        # DynamoDB rejects empty strings as GSI key values, so a blank index key
        # is stored as an absent attribute (which the index does not contain).
        def clear_blank_index_keys
          self.class.global_secondary_indexes.each_value do |index|
            attribute = index[:hash_key]&.to_sym
            next unless attribute && public_send(attribute) == ""

            public_send("#{attribute}=", nil)
          end
        end
      end

      module ClassMethods
        def create(attributes = {})
          new(attributes).tap(&:save)
        end

        def create!(attributes = {})
          new(attributes).tap(&:save!)
        end

        # Atomically adds `by` to a numeric attribute (DynamoDB UpdateItem ADD).
        # Returns false when no record with that id exists (ActiveRecord's
        # update_all would also touch nothing), so no phantom item is created.
        def increment_counter(attribute, id, by: 1)
          key_name = attributes.storage_name_for(hash_key)
          dynamodb_client.update_item(
            table_name: table_name,
            key: { key_name => attributes.attribute_for(hash_key).serialize(id) },
            update_expression: "ADD #counter :by",
            condition_expression: "attribute_exists(#key)",
            expression_attribute_names: {
              "#counter" => attributes.storage_name_for(attribute),
              "#key" => key_name
            },
            expression_attribute_values: { ":by" => by }
          )
          true
        rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
          false
        end

        # Creates this model's DynamoDB table, including any GSIs declared with
        # `global_secondary_index`. Safe to call when the table already exists:
        # it only applies missing GSIs and throughput changes.
        def devise_create_table!(read_capacity_units: 5, write_capacity_units: 5)
          model = self
          rcu = read_capacity_units
          wcu = write_capacity_units
          Aws::Record::TableConfig.define do |t|
            t.model_class model
            t.read_capacity_units rcu
            t.write_capacity_units wcu
            # Under PROVISIONED billing every GSI needs its own throughput.
            model.global_secondary_indexes.each_key do |index_name|
              t.global_secondary_index(index_name) do |i|
                i.read_capacity_units rcu
                i.write_capacity_units wcu
              end
            end
          end.migrate!
        end

        # Deletes every item in this model's table. Intended for test isolation.
        def devise_delete_all!
          scan.each(&:delete!)
        end
      end
    end
  end
end
