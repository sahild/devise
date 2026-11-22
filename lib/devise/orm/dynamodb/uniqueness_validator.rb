# frozen_string_literal: true

require "active_model"

# Load the default :taken message first, so ActiveRecord/Mongoid or the
# application's own translations still take precedence.
I18n.load_path.unshift(File.expand_path("locale/en.yml", __dir__))

module Devise
  module Orm
    module Dynamodb
      # DynamoDB has no unique secondary indexes, so neither Dynamoid nor
      # aws-record ship `validates_uniqueness_of`. This validator provides the
      # same options Devise relies on from ActiveRecord/Mongoid:
      #
      #   validates_uniqueness_of :email, allow_blank: true, case_sensitive: true,
      #                           scope: :account_id, if: :devise_will_save_change_to_email?
      #
      # Lookups go through the model's OrmAdapter (`to_adapter.find_all`), which
      # uses a Global Secondary Index on the attribute when one is declared and
      # falls back to a Scan otherwise.
      #
      # NOTE: like Rails' validator without a unique DB index, this is a
      # check-then-write and is not atomic. See the DynamoDB guide for details.
      class UniquenessValidator < ActiveModel::EachValidator
        def initialize(options)
          options = options.dup
          options[:case_sensitive] = true unless options.key?(:case_sensitive)
          super
        end

        def validate_each(record, attribute, value)
          if taken?(record, attribute, value)
            error_options = options.except(:case_sensitive, :scope, :conditions)
            error_options[:value] = value
            record.errors.add(attribute, :taken, **error_options)
          end
        end

        private

        def taken?(record, attribute, value)
          adapter = record.class.to_adapter
          conditions = scope_conditions(record)

          candidates =
            if options[:case_sensitive] || !value.is_a?(String)
              adapter.find_all(conditions.merge(attribute => value))
            else
              downcased = value.downcase
              adapter.find_all(conditions).select do |other|
                other_value = other.public_send(attribute)
                other_value.is_a?(String) && other_value.downcase == downcased
              end
            end

          candidates = candidates.select { |other| instance_exec(other, &options[:conditions]) } if options[:conditions]
          candidates.any? { |other| !same_record?(record, other) }
        end

        def scope_conditions(record)
          Array(options[:scope]).each_with_object({}) do |scope_attribute, conditions|
            conditions[scope_attribute] = record.public_send(scope_attribute)
          end
        end

        def same_record?(record, other)
          record.persisted? && other.to_key == record.to_key
        end
      end

      # Adds `validates_uniqueness_of` to a model class.
      module UniquenessValidation
        def validates_uniqueness_of(*attr_names)
          validates_with UniquenessValidator, _merge_attributes(attr_names)
        end
      end
    end
  end
end
