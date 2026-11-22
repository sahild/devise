# frozen_string_literal: true

require 'securerandom'
require 'active_model'

module Devise
  module Orm
    module Dynamodb
      # Raised when a lookup references an attribute the model does not declare.
      class UnknownAttributeError < ArgumentError; end

      # Raised when a Devise model uses a table layout Devise cannot work with.
      class UnsupportedSchemaError < StandardError; end

      # Serializes times as ISO 8601 with microsecond precision. aws-record's
      # default formatter truncates times to whole seconds, which is lossy for
      # Devise timestamps (e.g. remember_created_at). Use it with:
      #
      #   time_attr :remember_created_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
      module TimeFormatter
        def self.format(time)
          time.utc.iso8601(6)
        end
      end

      # Dirty tracking helpers Devise relies on (see Devise::Orm), implemented
      # on top of four per-library primitives:
      #
      #   devise_attribute_in_database(name)
      #   devise_will_save_change_to_attribute?(name)
      #   devise_previous_change(name)   # => [old, new] or nil
      #   devise_force_change!(name)
      module DirtyTracking
        def devise_email_before_last_save
          change = devise_previous_change(:email)
          change ? change.first : email
        end

        def devise_email_in_database
          devise_attribute_in_database(:email)
        end

        def devise_saved_change_to_email?
          devise_saved_change_to_attribute?(:email)
        end

        def devise_saved_change_to_encrypted_password?
          devise_saved_change_to_attribute?(:encrypted_password)
        end

        def devise_will_save_change_to_email?
          devise_will_save_change_to_attribute?(:email)
        end

        def devise_unconfirmed_email_will_change!
          # Force unconfirmed_email into the next write even if its value is
          # unchanged, to avoid the race condition described in #5783.
          devise_force_change!(:unconfirmed_email)
        end

        def devise_respond_to_and_will_save_change_to_attribute?(attribute)
          respond_to?("#{attribute}_changed?") && devise_will_save_change_to_attribute?(attribute)
        end

        private

        def devise_saved_change_to_attribute?(name)
          change = devise_previous_change(name)
          !!change && change.first != change.last
        end
      end

      # Validation helpers shared by both libraries.
      module Validations
        extend ActiveSupport::Concern

        # `UniquenessValidator` is also set on this module (see
        # uniqueness_validator.rb) so `validates :email, uniqueness: true` works.

        module ClassMethods
          # Same API as Active Record's validates_uniqueness_of. Supports the
          # :scope, :case_sensitive (true only), :message, :allow_nil,
          # :allow_blank, :if and :unless options.
          def validates_uniqueness_of(*attr_names)
            validates_with ::Devise::Orm::Dynamodb::UniquenessValidator, _merge_attributes(attr_names)
          end
        end
      end

      # Methods resolving a model's primary key, shared by both libraries.
      module PrimaryKey
        # Devise reads `id` (e.g. Lockable#increment_failed_attempts and
        # ActiveModel::Conversion#to_key). Models whose partition key is not
        # called `id` get a read-only `id` returning the partition key value.
        def method_missing(name, *args, &block)
          if name == :id && args.empty? && devise_alias_id?
            devise_primary_key_value
          else
            super
          end
        end

        def respond_to_missing?(name, include_private = false)
          (name == :id && devise_alias_id?) || super
        end

        private

        def devise_alias_id?
          backend = Devise::Orm::Dynamodb.backend_for(self.class)
          backend.hash_key(self.class) != :id
        end

        def devise_primary_key_value
          backend = Devise::Orm::Dynamodb.backend_for(self.class)
          backend.read(self, backend.hash_key(self.class))
        end
      end

      module Backends
        # Backend for models including Dynamoid::Document.
        module Dynamoid
          # Behaviour mixed into Dynamoid models when they call `devise`.
          module ModelCompat
            extend ActiveSupport::Concern
            include DirtyTracking
            include Validations
            include PrimaryKey

            module ClassMethods
              # Used by Lockable to atomically bump failed_attempts.
              def increment_counter(attribute, id)
                inc(id, attribute.to_sym => 1)
              end
            end

            # Dynamoid's #update/#update! take conditions and a block of
            # low-level update operations. Devise (and Active Record code in
            # general) calls them with a hash of attributes to assign and save,
            # so that form is supported here; the block form still works.
            def update(attributes = nil, &block)
              return super(attributes || {}, &block) if block

              assign_attributes(attributes || {})
              save
            end

            def update!(attributes = nil, &block)
              return super(attributes || {}, &block) if block

              assign_attributes(attributes || {})
              save!
            end

            # Dynamoid runs after_create/after_update callbacks before moving
            # pending changes to previous_changes, so while a save is running
            # "the change being saved" is still in #changes.
            # Saving an item deleted since it was loaded returns false (save!
            # raises) instead of recreating it, matching the aws-record
            # integration. Dynamoid detects it with a conditional write.
            def save(*)
              devise_while_saving do
                devise_forget_primary_key_change
                super
              end
            rescue ::Dynamoid::Errors::StaleObjectError
              errors.add(:base, "#{self.class.model_name.human} no longer exists")
              false
            end

            def save!(*)
              devise_while_saving do
                devise_forget_primary_key_change
                super
              end
            end

            private

            # A record saved again from one of its own after_create callbacks
            # is already persisted but its changes, including the generated
            # partition key, are not applied yet. DynamoDB rejects writes that
            # touch a key attribute, so drop that pending change.
            def devise_forget_primary_key_change
              key = self.class.hash_key.to_s
              clear_attribute_changes([key]) if persisted? && attribute_changed?(key)
            end

            def devise_while_saving
              saving_before = @devise_saving
              @devise_saving = true
              yield
            ensure
              @devise_saving = saving_before
            end

            def devise_attribute_in_database(name)
              attribute_was(name.to_s)
            end

            def devise_will_save_change_to_attribute?(name)
              name = name.to_s
              attribute_changed?(name) && attribute_was(name) != read_attribute(name)
            end

            def devise_previous_change(name)
              (@devise_saving ? changes : previous_changes)[name.to_s]
            end

            def devise_force_change!(name)
              public_send("#{name}_will_change!")
            end

            # Dynamoid only keeps attributes that have been assigned, so make
            # serialization (to_json, inspect) list every declared field, as
            # Active Record and Mongoid do.
            def attribute_names_for_serialization
              self.class.attributes.keys.map(&:to_s)
            end
          end

          module_function

          def hash_key(model)
            model.hash_key.to_sym
          end

          def range_key(model)
            model.range_key
          end

          def hash_key_storage_name(model)
            hash_key(model).to_s
          end

          def attribute_names(model)
            model.attributes.keys.map(&:to_sym)
          end

          def attribute?(model, name)
            model.attributes.key?(name.to_sym)
          end

          def string_attribute?(model, name)
            model.attributes[name.to_sym][:type] == :string
          end

          # Name of a global secondary index partitioned by +attribute+, if any.
          def index_for(model, attribute)
            index = model.global_secondary_indexes.values.find { |i| i.hash_key.to_sym == attribute }
            index && index.name
          end

          def index_names(model)
            model.global_secondary_indexes.values.map { |i| i.name.to_s }
          end

          def find_by_key(model, value)
            model.find(value, consistent_read: true, raise_error: false)
          end

          # Partition key values of the items whose +attribute+ equals +value+,
          # read from the global secondary index +index_name+.
          # Queried with the SDK client directly: Dynamoid's criteria add a
          # `type IN (...)` filter for models with a type field, which fails on
          # indexes that do not project it (e.g. keys-only). The adapter checks
          # the class of each re-read item instead.
          def query_index_keys(model, index_name, attribute, value)
            key = hash_key_storage_name(model)
            dumped = ::Dynamoid::Dumping.dump_field(value, model.attributes[attribute])

            Enumerator.new do |yielder|
              start_key = nil
              loop do
                params = {
                  table_name: model.table_name,
                  index_name: index_name.to_s,
                  key_condition_expression: '#attribute = :value',
                  expression_attribute_names: { '#attribute' => attribute.to_s },
                  expression_attribute_values: { ':value' => dumped }
                }
                params[:exclusive_start_key] = start_key if start_key
                page = client(model).query(params)
                page.items.each { |item| yielder << item[key] }
                start_key = page.last_evaluated_key
                break if start_key.nil? || start_key.empty?
              end
            end.lazy
          end

          # Name of the attribute storing the record's class name, if the
          # model declares one (Dynamoid's single table inheritance).
          def type_attribute(model)
            field = model.inheritance_field.to_sym
            field if model.attributes.key?(field)
          end

          # Strongly consistent Scan. +filters+ (string equality conditions)
          # are evaluated by DynamoDB; the adapter re-checks every condition.
          def scan(model, filters)
            chain = ::Dynamoid::Criteria::Chain.new(model).consistent
            chain = chain.where(filters) if filters.any?
            chain
          end

          def read(record, attribute)
            record.read_attribute(attribute)
          end

          def not_found_error(model, id)
            ::Dynamoid::Errors::RecordNotFound.new("Couldn't find #{model.name} with primary key #{id.inspect}")
          end

          def table_name(model)
            model.table_name
          end

          def client(_model)
            ::Dynamoid.adapter.client
          end

          def table_exists?(model)
            ::Dynamoid.adapter.list_tables.include?(table_name(model))
          end

          def create_table(model)
            model.create_table(sync: true)
          end

          def drop_table(model)
            ::Dynamoid.adapter.delete_table(table_name(model), sync: true)
          end
        end

        # Backend for models including Aws::Record.
        module AwsRecord
          # aws-record models are plain DynamoDB mappers: they have no
          # validations, callbacks, ActiveModel dirty tracking or
          # serialization. This module adds the subset of the Active Record
          # API Devise (and its controllers and views) rely on.
          module ModelCompat
            extend ActiveSupport::Concern
            # Concern dependencies are included into the model before this
            # module, so the overrides below (valid?, save, ...) take precedence.
            include ::ActiveModel::Validations
            include ::ActiveModel::Validations::Callbacks
            include ::ActiveModel::Conversion
            include ::ActiveModel::Serializers::JSON
            include DirtyTracking
            include Validations
            include PrimaryKey

            included do
              extend ::ActiveModel::Callbacks
              define_model_callbacks :save, :create, :update, :destroy
            end

            module ClassMethods
              def create(attributes = {}, &block)
                new(attributes, &block).tap(&:save)
              end

              def create!(attributes = {}, &block)
                new(attributes, &block).tap(&:save!)
              end

              # Used by Lockable to atomically bump failed_attempts.
              def increment_counter(attribute, id)
                attribute = attributes.attribute_for(attribute.to_sym)
                key = attributes.attribute_for(hash_key)

                dynamodb_client.update_item(
                  table_name: table_name,
                  key: { key.database_name => key.serialize(id) },
                  update_expression: 'ADD #counter :one',
                  condition_expression: 'attribute_exists(#key)',
                  expression_attribute_names: { '#counter' => attribute.database_name, '#key' => key.database_name },
                  expression_attribute_values: { ':one' => 1 }
                )
                true
              rescue ::Aws::DynamoDB::Errors::ConditionalCheckFailedException
                false
              end

              # Subclasses of a Devise aws-record model share its table (like
              # Active Record single table inheritance) unless they call
              # set_table_name themselves. Declare `string_attr :type` on the
              # parent to record each item's class: lookups then only return
              # items of the class (or its subclasses), like Active Record STI.
              # Without it, every class sees every item of the table.
              def inherited(subclass)
                super
                subclass.send(:include, ::Aws::Record)
                subclass.define_singleton_method(:table_name) do
                  @table_name || superclass.table_name
                end
              end
            end

            def initialize(*args, &block)
              super(*args)
              yield self if block
            end

            def valid?(context = nil)
              super(context || (new_record? ? :create : :update))
            end
            alias_method :validate, :valid?

            def save(options = {})
              options = options.dup
              validate = options.key?(:validate) ? options.delete(:validate) : true
              options.delete(:touch)
              return false if validate && !valid?

              devise_create_or_update(options) { |opts| super(opts) }
            end

            def save!(options = {})
              return true if save(options)

              message = errors.any? ? errors.full_messages.join(', ') : 'record was not saved'
              raise ::Aws::Record::Errors::ValidationError, "Validation failed: #{message}"
            end

            def update_attribute(name, value)
              public_send("#{name}=", value)
              save(validate: false)
            end

            # Returns self, or false if a before_destroy callback halted it.
            def destroy
              destroyed = run_callbacks(:destroy) { delete!; true }
              destroyed ? self : false
            end

            def delete
              delete!
              self
            end

            def reload
              key = { self.class.hash_key => public_send(self.class.hash_key) }
              fresh = self.class.find_with_opts(key: key, consistent_read: true)
              raise ::Aws::Record::Errors::NotFound, "Couldn't find #{self.class.name} with primary key #{key.values.first.inspect}" unless fresh

              @data = fresh.instance_variable_get(:@data)
              @devise_previous_changes = {}
              self
            end

            def [](name)
              public_send(name) if self.class.attributes.present?(name.to_sym)
            end

            def []=(name, value)
              public_send("#{name}=", value)
            end

            # Attribute name => value, used by ActiveModel serialization.
            def attributes
              self.class.attribute_names.each_with_object({}) do |name, hash|
                hash[name.to_s] = public_send(name)
              end
            end

            def changed?
              dirty?
            end

            def changed
              dirty.map(&:to_s)
            end

            def changes
              dirty.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |name, hash|
                hash[name] = [attribute_was(name), public_send(name)]
              end
            end

            def previous_changes
              ActiveSupport::HashWithIndifferentAccess.new(@devise_previous_changes || {})
            end

            def attribute_changed?(name)
              name = name.to_sym
              self.class.attributes.present?(name) && attribute_dirty?(name)
            end

            def attribute_previously_changed?(name)
              previous_changes.key?(name.to_s)
            end

            # Equality by partition key, like Active Record.
            def ==(other)
              super || (other.instance_of?(self.class) && persisted? &&
                devise_primary_key_value_for_equality == other.send(:devise_primary_key_value_for_equality))
            end
            alias_method :eql?, :==

            def hash
              persisted? ? [self.class, devise_primary_key_value_for_equality].hash : super
            end

            # Provides the `<attribute>_changed?`, `<attribute>_previously_changed?`
            # and `<attribute>_will_change!` methods Active Record and Mongoid
            # define, for attributes declared before or after `devise`.
            # Also provides `<attribute>?` (true when the value is present).
            DIRTY_METHOD = /\A(.+?)(_changed\?|_previously_changed\?|_will_change!|\?)\z/

            def method_missing(name, *args, &block)
              match = DIRTY_METHOD.match(name.to_s)
              return super unless match && args.empty? && self.class.attributes.present?(match[1].to_sym)

              attribute = match[1]
              case match[2]
              when '_changed?' then attribute_changed?(attribute)
              when '_previously_changed?' then attribute_previously_changed?(attribute)
              when '_will_change!' then attribute_dirty!(attribute.to_sym)
              when '?' then public_send(attribute).present?
              end
            end

            def respond_to_missing?(name, include_private = false)
              match = DIRTY_METHOD.match(name.to_s)
              (match && self.class.attributes.present?(match[1].to_sym)) || super
            end

            private

            def devise_primary_key_value_for_equality
              public_send(self.class.hash_key)
            end

            # Validation already ran in #save; skip aws-record's own check.
            def _invalid_record?(_opts)
              false
            end

            def devise_create_or_update(options)
              creating = new_record?

              result = run_callbacks(:save) do
                run_callbacks(creating ? :create : :update) do
                  devise_assign_primary_key if creating
                  devise_assign_type if creating
                  devise_blank_strings_to_nil
                  devise_touch_timestamps(creating)

                  pending = changes
                  if creating
                    yield options
                  elsif pending.any?
                    yield devise_only_if_exists(options)
                  end
                  @devise_previous_changes = pending
                  true
                end
              end

              result != false
            rescue ::Aws::DynamoDB::Errors::ConditionalCheckFailedException
              # The item was deleted since it was loaded: nothing was written.
              errors.add(:base, "#{self.class.model_name.human} no longer exists")
              false
            end

            # Updates must not recreate an item deleted in the meantime (e.g. a
            # user destroyed while another request still holds the record), so
            # they are conditional on the item existing, as with Dynamoid.
            def devise_only_if_exists(options)
              return options if options.key?(:condition_expression)

              key = self.class.attributes.storage_name_for(self.class.hash_key)
              names = (options[:expression_attribute_names] || {}).merge('#devise_key' => key)
              options.merge(condition_expression: 'attribute_exists(#devise_key)', expression_attribute_names: names)
            end

            def devise_assign_type
              return unless Backends::AwsRecord.type_attribute(self.class)

              self.type = self.class.name if self[:type].blank?
            end

            # DynamoDB rejects empty strings in key and index key attributes
            # and aws-record cannot write them as plain attributes, so they are
            # stored as missing attributes (read back as nil), as Dynamoid does
            # by default.
            def devise_blank_strings_to_nil
              self.class.attributes.attributes.each do |name, attribute|
                next unless attribute.dynamodb_type == 'S'

                public_send("#{name}=", nil) if @data.raw_value(name) == ''
              end
            end

            def devise_assign_primary_key
              key = self.class.hash_key
              return unless public_send(key).blank?
              return unless self.class.attributes.attribute_for(key).dynamodb_type == 'S'

              public_send("#{key}=", SecureRandom.uuid)
            end

            def devise_touch_timestamps(creating)
              return unless creating || dirty?

              now = Time.now.utc
              if creating && self.class.attributes.present?(:created_at) && created_at.nil?
                self.created_at = now
              end
              self.updated_at = now if self.class.attributes.present?(:updated_at)
            end

            def devise_attribute_in_database(name)
              attribute_was(name.to_sym)
            end

            def devise_will_save_change_to_attribute?(name)
              name = name.to_sym
              attribute_changed?(name) && attribute_was(name) != public_send(name)
            end

            def devise_previous_change(name)
              previous_changes[name.to_s]
            end

            def devise_force_change!(name)
              attribute_dirty!(name.to_sym)
            end
          end

          module_function

          def hash_key(model)
            model.hash_key
          end

          def range_key(model)
            model.range_key
          end

          def hash_key_storage_name(model)
            model.attributes.storage_name_for(hash_key(model))
          end

          def attribute_names(model)
            model.attribute_names
          end

          def attribute?(model, name)
            model.attributes.present?(name.to_sym)
          end

          def string_attribute?(model, name)
            model.attributes.attribute_for(name.to_sym).dynamodb_type == 'S'
          end

          def index_for(model, attribute)
            name, _ = model.global_secondary_indexes.find { |_, options| options[:hash_key] == attribute }
            name
          end

          def index_names(model)
            model.global_secondary_indexes.keys.map(&:to_s)
          end

          def find_by_key(model, value)
            model.find_with_opts(key: { hash_key(model) => value }, consistent_read: true)
          end

          # Name of the attribute storing the record's class name, if the model
          # declares a string attribute called `type` (see ModelCompat#inherited).
          def type_attribute(model)
            :type if model.attributes.present?(:type) && string_attribute?(model, :type)
          end

          def query_index_keys(model, index_name, attribute, value)
            attribute = model.attributes.attribute_for(attribute)

            model.query(
              index_name: index_name.to_s,
              key_condition_expression: '#attribute = :value',
              expression_attribute_names: { '#attribute' => attribute.database_name },
              expression_attribute_values: { ':value' => attribute.serialize(value) }
            ).lazy.map { |record| record.public_send(hash_key(model)) }
          end

          # Strongly consistent Scan. +filters+ (string equality conditions)
          # are evaluated by DynamoDB; the adapter re-checks every condition.
          def scan(model, filters)
            options = { consistent_read: true }

            if filters.any?
              names = {}
              values = {}
              expressions = filters.each_with_index.map do |(name, value), i|
                attribute = model.attributes.attribute_for(name)
                names["#a#{i}"] = attribute.database_name
                values[":v#{i}"] = attribute.serialize(value)
                "#a#{i} = :v#{i}"
              end

              options.update(
                filter_expression: expressions.join(' AND '),
                expression_attribute_names: names,
                expression_attribute_values: values
              )
            end

            model.scan(options)
          end

          def read(record, attribute)
            record.public_send(attribute)
          end

          def not_found_error(model, id)
            ::Aws::Record::Errors::NotFound.new("Couldn't find #{model.name} with primary key #{id.inspect}")
          end

          def table_name(model)
            model.table_name
          end

          def client(model)
            model.dynamodb_client
          end

          def table_exists?(model)
            model.table_exists?
          end

          # Creates the table with on-demand billing. Global secondary indexes
          # must declare a :projection (see the README).
          def create_table(model)
            migration = ::Aws::Record::TableMigration.new(model, client: client(model))
            migration.create!(billing_mode: 'PAY_PER_REQUEST')
            client(model).wait_until(:table_exists, table_name: table_name(model)) { |w| w.delay = 1 }
          end

          def drop_table(model)
            client(model).delete_table(table_name: table_name(model))
            client(model).wait_until(:table_not_exists, table_name: table_name(model)) { |w| w.delay = 1 }
          rescue ::Aws::DynamoDB::Errors::ResourceNotFoundException
            nil
          end
        end
      end
    end
  end
end
