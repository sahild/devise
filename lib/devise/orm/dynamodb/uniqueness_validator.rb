# frozen_string_literal: true

require 'active_model'

module Devise
  module Orm
    module Dynamodb
      # Uniqueness validation for DynamoDB models, mirroring Active Record's
      # `validates_uniqueness_of` (used by Devise's :validatable module).
      #
      # The lookup goes through Devise::Orm::Dynamodb::Adapter, so it uses a
      # global secondary index on the attribute when one exists and falls back
      # to a strongly consistent Scan otherwise.
      #
      # Like Active Record without a unique database index, this check is not
      # atomic: two concurrent writes can still both succeed. See the README for
      # how to enforce uniqueness with a conditional write if you need that.
      class UniquenessValidator < ::ActiveModel::EachValidator
        def initialize(options)
          if options.key?(:case_sensitive) && !options[:case_sensitive]
            raise ArgumentError, "case_sensitive: false is not supported for DynamoDB models. " \
              "Normalize the value instead (Devise does this for config.case_insensitive_keys)."
          end

          unsupported = options.keys & [:conditions, :if_exists]
          if unsupported.any?
            raise ArgumentError, "#{unsupported.map(&:inspect).join(', ')} not supported by the DynamoDB uniqueness validator"
          end

          super
        end

        def validate_each(record, attribute, value)
          conditions = { attribute => value }
          Array(options[:scope]).each do |scope|
            conditions[scope] = record.public_send(scope)
          end

          taken = record.class.to_adapter.each_match(conditions, all_classes: true).any? do |other|
            !same_record?(record, other)
          end
          return unless taken

          error_options = options.except(:case_sensitive, :scope)
          error_options[:value] = value
          record.errors.add(attribute, :taken, **error_options)
        end

        private

        def same_record?(record, other)
          return false if record.new_record?

          backend = Devise::Orm::Dynamodb.backend_for(record.class)
          key = backend.hash_key(record.class)
          backend.read(record, key) == backend.read(other, key)
        end
      end

      Validations::UniquenessValidator = UniquenessValidator
    end
  end
end
