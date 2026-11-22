# frozen_string_literal: true

module Shim
  extend ::ActiveSupport::Concern

  included do
    # Devise tests run against DynamoDB Local in on-demand mode. Every model
    # shares one table per root class, like Active Record STI.
    table capacity_mode: :on_demand
  end

  module ClassMethods
    def find_by_email(email)
      to_adapter.find_first(email: email)
    end

    def find_by(conditions)
      to_adapter.find_first(conditions)
    end

    def destroy_all
      to_adapter.find_all.each(&:destroy)
    end

    # Minimal stand-in for Active Record's `where(...).update_all(...)`: writes
    # the attributes directly, skipping validations and callbacks.
    def where(conditions)
      return super unless conditions.is_a?(Hash) && conditions.keys.map(&:to_sym) == [:id]

      model = self
      Struct.new(:ids) do
        define_method(:update_all) do |attributes|
          ids.each { |id| model.update_fields(id, attributes) }
        end
      end.new(Array(conditions.values.first))
    end
  end
end
