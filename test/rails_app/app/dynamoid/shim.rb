# frozen_string_literal: true

module Shim
  extend ::ActiveSupport::Concern

  module ClassMethods
    def order(attribute)
      all.to_a.sort_by { |record| record.public_send(attribute) }
    end

    def find_by_email(email)
      find_by(email: email)
    end

    def find_by(conditions)
      to_adapter.find_first(conditions)
    end

    def destroy_all
      all.to_a.each(&:destroy)
    end

    # ActiveRecord-style `where(...).update_all(attrs)`: writes directly,
    # without validations or callbacks.
    def where(conditions = {}, *args)
      ShimRelation.new(self, super)
    end
  end

  class ShimRelation < SimpleDelegator
    def initialize(model, chain)
      super(chain)
      @model = model
    end

    def update_all(attributes)
      to_a.each { |record| @model.update_fields(record.hash_key, attributes) }
    end
  end

  # overwrite equality (because some devise tests use this for asserting model equality)
  def ==(other)
    other.is_a?(self.class) && id == other.id
  end
end
