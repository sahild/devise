# frozen_string_literal: true

require 'orm_adapter'

module Devise
  module Orm
    module Dynamodb
      # OrmAdapter implementation for DynamoDB models (Dynamoid or aws-record).
      #
      # DynamoDB can only look items up efficiently by primary key or through a
      # secondary index, so equality lookups are planned as follows:
      #
      #   1. The conditions include the partition key (or `id`): GetItem.
      #   2. A condition is on an attribute that is the partition key of a
      #      global secondary index: Query the index, then re-read each
      #      candidate with a strongly consistent GetItem (index reads are
      #      eventually consistent).
      #   3. Otherwise: a strongly consistent Scan (a warning is logged once).
      #
      # Every candidate is re-checked against all the conditions in Ruby, so
      # the result is the same whichever plan is used.
      #
      # Models sharing a table (subclasses) are told apart by their type
      # attribute when they declare one (`field :type` with Dynamoid,
      # `string_attr :type` with aws-record): a model then only sees items of
      # its own class or its subclasses, as with Active Record STI.
      class Adapter < ::OrmAdapter::Base
        def initialize(klass)
          super
          @backend = Devise::Orm::Dynamodb.backend_for(klass)
          validate_schema!
        end

        def column_names
          @backend.attribute_names(klass).map(&:to_s)
        end

        def get!(id)
          get(id) || raise(@backend.not_found_error(klass, wrap_key(id)))
        end

        def get(id)
          id = wrap_key(id)
          return nil if id.blank?

          record = @backend.find_by_key(klass, id)
          record if record && of_this_class?(record)
        end

        def find_first(options = {})
          conditions, order = extract_conditions!(options.dup)
          return find_all(conditions: conditions, order: order, limit: 1).first if order.any?

          each_match(conditions).first
        end

        # Ordering, limit and offset are applied in memory after reading every
        # matching item, so avoid them on large result sets.
        def find_all(options = {})
          conditions, order, limit, offset = extract_conditions!(options.dup)
          records = each_match(conditions).to_a
          records = sort(records, order) if order.any?
          records = records.drop(offset) if offset
          records = records.first(limit) if limit
          records
        end

        def create!(attributes = {})
          klass.create!(attributes)
        end

        def destroy(object)
          object.destroy if valid_object?(object)
        end

        # Lazily yields the records matching all +conditions+. With
        # +all_classes+, items of other classes sharing the table are included
        # (used by the uniqueness validation, which spans the whole table like
        # Active Record's does for STI models).
        def each_match(conditions, all_classes: false)
          conditions = normalize_conditions(conditions)
          candidates(conditions).select do |record|
            record && (all_classes || of_this_class?(record)) && matches?(record, conditions)
          end
        end

        protected

        def valid_object?(object)
          object.is_a?(klass)
        end

        private

        def validate_schema!
          return unless @backend.range_key(klass)

          raise UnsupportedSchemaError, "#{klass.name} has a sort (range) key. Devise models stored " \
            "in DynamoDB must use a table with a partition key only."
        end

        def normalize_conditions(conditions)
          hash_key = @backend.hash_key(klass)

          conditions.each_with_object({}) do |(name, value), normalized|
            name = name.to_sym
            name = hash_key if name == :id

            unless @backend.attribute?(klass, name)
              raise UnknownAttributeError, "#{klass.name} has no attribute #{name.inspect}. " \
                "Declare it as a field on the model to use it in Devise lookups."
            end

            normalized[name] = value
          end
        end

        def candidates(conditions)
          hash_key = @backend.hash_key(klass)
          indexed = index_for(conditions)

          if conditions.key?(hash_key)
            [get(conditions[hash_key])].lazy
          elsif indexed
            attribute, index = indexed
            @backend.query_index_keys(klass, index, attribute, conditions[attribute])
              .map { |key| @backend.find_by_key(klass, key) }
          else
            Devise::Orm::Dynamodb.warn_scan(klass, conditions.keys) if conditions.any?
            filters = conditions.select { |name, value| server_filterable?(name, value) }
            @backend.scan(klass, filters).lazy
          end
        end

        # The first condition whose attribute partitions a global secondary
        # index. DynamoDB index keys cannot hold empty strings, so blank values
        # can only be found with a Scan.
        def index_for(conditions)
          conditions.each do |name, value|
            next unless server_filterable?(name, value)

            index = @backend.index_for(klass, name)
            return [name, index] if index
          end
          nil
        end

        def server_filterable?(name, value)
          value.is_a?(String) && !value.empty? && @backend.string_attribute?(klass, name)
        end

        # False for items of a shared table written by another model class
        # that is not this class or one of its subclasses. Only possible to
        # tell when the model declares a type attribute; untyped items are
        # visible to every class.
        def of_this_class?(record)
          type = @backend.type_attribute(klass)
          return true unless type

          stored = @backend.read(record, type)
          return true if stored.blank?

          stored_class = stored.to_s.safe_constantize
          !!(stored_class && stored_class <= klass)
        end

        def matches?(record, conditions)
          conditions.all? do |name, expected|
            values_match?(@backend.read(record, name), expected)
          end
        end

        # Devise stringifies lookup values (see Devise::ParameterFilter), so a
        # value matches an attribute of another type with the same string form
        # (e.g. "3" and 3, or 5 and "5"). Empty strings and nil are equivalent,
        # because DynamoDB libraries commonly store empty strings as missing
        # attributes.
        def values_match?(actual, expected)
          actual = nil if actual == ''
          expected = nil if expected == ''

          return true if actual == expected
          return false if actual.nil? || expected.nil?

          (actual.is_a?(String) || expected.is_a?(String)) && actual.to_s == expected.to_s
        end

        def sort(records, order)
          records.sort do |a, b|
            comparison = 0
            order.each do |attribute, direction|
              x = @backend.read(a, attribute.to_sym)
              y = @backend.read(b, attribute.to_sym)
              comparison = compare(x, y)
              comparison = -comparison if direction == :desc
              break unless comparison.zero?
            end
            comparison
          end
        end

        # nil sorts first, like NULL in ascending SQL order on most databases.
        def compare(x, y)
          return 0 if x.nil? && y.nil?
          return -1 if x.nil?
          return 1 if y.nil?

          (x <=> y) || x.to_s <=> y.to_s
        end
      end
    end
  end
end
