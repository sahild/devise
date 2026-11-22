# frozen_string_literal: true

require "dynamoid"
require "orm_adapter"
require "devise/orm/dynamodb/uniqueness_validator"

module Dynamoid
  module Document
    # OrmAdapter for Dynamoid models. Dynamoid ships none, so Devise's
    # orm_adapter API is implemented here on top of Dynamoid's finders.
    #
    # Lookups use a Global Secondary Index when the queried attribute has one
    # (Dynamoid selects it automatically) and fall back to a Scan otherwise.
    class OrmAdapter < ::OrmAdapter::Base
      # get a list of column names for a given class
      def column_names
        klass.attributes.keys.map(&:to_s)
      end

      # @see OrmAdapter::Base#get!
      def get!(id)
        klass.find(wrap_key(id))
      end

      # @see OrmAdapter::Base#get
      def get(id)
        key = wrap_key(id)
        key.blank? ? nil : klass.find(key, raise_error: false)
      end

      # @see OrmAdapter::Base#find_first
      def find_first(options = {})
        find_all(options).first
      end

      # @see OrmAdapter::Base#find_all
      def find_all(options = {})
        conditions, order, limit, offset = extract_conditions!(options)
        records = matching_records(conditions)
        records = sort_records(records, order) if order.any?
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

    protected

      # DynamoDB cannot query a GSI for a missing (NULL) attribute, and
      # Dynamoid's `where(attr: nil)` does not match items without the
      # attribute. Dynamoid also stores "" as NULL (store_empty_string_as_nil),
      # so both nil and "" conditions are applied in Ruby on the candidates.
      def matching_records(conditions)
        queryable, blank_conditions = conditions.partition { |_key, value| !blank_value?(value) }
        scope = queryable.empty? ? klass.all : klass.where(queryable.to_h)

        scope.to_a.select do |record|
          blank_conditions.all? { |key, _value| blank_value?(record.public_send(key)) }
        end
      end

      def blank_value?(value)
        value.nil? || value == ""
      end

      def sort_records(records, order)
        records.sort do |left, right|
          order.inject(0) do |result, (attribute, direction)|
            next result unless result.zero?

            comparison = compare_values(left.public_send(attribute), right.public_send(attribute))
            direction == :desc ? -comparison : comparison
          end
        end
      end

      def compare_values(left, right)
        return 0 if left.nil? && right.nil?
        return -1 if left.nil?
        return 1 if right.nil?

        (left <=> right) || 0
      end
    end
  end
end

module Devise
  module Orm
    # Support module for Dynamoid models. Provides the dirty-tracking
    # primitives used by Devise::Orm::DirtyTrackingDynamodbMethods.
    module DynamoidSupport
      def self.model?(klass)
        klass.is_a?(Class) && klass.include?(::Dynamoid::Document)
      end

      # Class-level helpers added to every Dynamoid model.
      module ModelClassMethods
        # Atomically adds 1 (or the given amount) to a numeric attribute. This
        # is a DynamoDB ADD update, so concurrent increments are not lost.
        def increment_counter(attribute, id)
          inc(id, attribute.to_sym => 1)
        end
      end

      # Mixed into Dynamoid::Document, so every Dynamoid model gets these
      # instance methods.
      #
      # Dynamoid applies pending changes (changes_applied) only after the
      # save callbacks have run, so inside after_update the change is still
      # pending. Devise also reads the "last save" values after #save returns,
      # when the change has moved to previous_changes. The @devise_saving flag
      # tells the two phases apart.
      module InstanceMethods
        def save(*args)
          devise_clear_key_changes_if_persisted
          devise_within_save { super(*args) }
        end

        def save!(*args)
          devise_clear_key_changes_if_persisted
          devise_within_save { super(*args) }
        end

        # Dynamoid keys attributes by Symbol, so ActiveModel's
        # serializable_hash(only:/except:) (which compares Strings) would
        # ignore Devise's UNSAFE_ATTRIBUTES_FOR_SERIALIZATION list.
        # Include every declared field (even nil ones), as ActiveRecord and
        # Mongoid do; Dynamoid's attributes hash omits unset fields.
        def attribute_names_for_serialization
          (self.class.attributes.keys | attributes.keys).map(&:to_s)
        end

        # ActiveRecord-style `update(attributes)`: assigns, then saves with
        # validations and callbacks. Dynamoid's own `update` is a conditional
        # low-level write that does not accept attribute hashes, and Devise
        # calls `update(params)` (database_authenticatable#update_with_password).
        def update(attributes = {}, &block)
          return super(&block) if block_given?

          assign_attributes(attributes)
          save
        end

        # Bang variant of #update(attributes): raises
        # Dynamoid::Errors::DocumentNotValid when validations fail.
        def update!(attributes = {}, &block)
          return super(&block) if block_given?

          assign_attributes(attributes)
          save!
          self
        end

        def devise_attribute_will_save_change?(attribute)
          attribute_changed?(attribute.to_s)
        end

        def devise_attribute_in_database(attribute)
          attribute_was(attribute.to_s)
        end

        def devise_attribute_saved_change?(attribute)
          if @devise_saving
            attribute_changed?(attribute.to_s)
          else
            previous_changes.include?(attribute.to_s)
          end
        end

        def devise_attribute_before_last_save(attribute)
          if @devise_saving
            attribute_was(attribute.to_s)
          elsif previous_changes.include?(attribute.to_s)
            previous_changes[attribute.to_s].first
          else
            read_attribute(attribute)
          end
        end

        # Dynamoid only writes attributes listed in `changed`, so marking the
        # attribute as changed (with its current value as the "before" value)
        # makes the next save persist it even when its value is unchanged.
        def devise_attribute_force_change!(attribute)
          set_attribute_was(attribute.to_s, read_attribute(attribute))
        end

      private

        # A save nested in an after_create callback (e.g. `after_create :save`)
        # runs before Dynamoid applies the creation's changes, so the primary
        # key still looks changed and DynamoDB rejects updating it. Keys of a
        # persisted record can never change, so drop them from the change set.
        def devise_clear_key_changes_if_persisted
          return if new_record?

          clear_attribute_changes([self.class.hash_key, self.class.range_key].compact.map(&:to_s))
        end

        def devise_within_save
          previous_saving = @devise_saving
          @devise_saving = true
          yield
        ensure
          @devise_saving = previous_saving
        end
      end
    end
  end
end

ActiveSupport.on_load(:dynamoid) do
  Dynamoid::Document::ClassMethods.send :include, Devise::Models
  Dynamoid::Document::ClassMethods.send :include, ::OrmAdapter::ToAdapter
  Dynamoid::Document::ClassMethods.send :include, Devise::Orm::Dynamodb::UniquenessValidation
  Dynamoid::Document::ClassMethods.send :include, Devise::Orm::DynamoidSupport::ModelClassMethods
  Dynamoid::Document.send :include, Devise::Orm::DynamoidSupport::InstanceMethods
end
