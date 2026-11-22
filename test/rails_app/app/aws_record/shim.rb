# frozen_string_literal: true

module Shim
  extend ::ActiveSupport::Concern

  module ClassMethods
    def order(attribute)
      to_adapter.find_all(order: attribute)
    end

    # ActiveRecord-style find by primary key (aws-record's #find takes a key hash).
    def find(id_or_key)
      return super if id_or_key.is_a?(Hash)

      to_adapter.get!(id_or_key)
    end

    def find_by_email(email)
      find_by(email: email)
    end

    def find_by(conditions)
      to_adapter.find_first(conditions)
    end

    def where(conditions)
      ShimRelation.new(self, conditions)
    end

    def count
      scan.count
    end

    def destroy_all
      to_adapter.find_all.each(&:destroy)
    end
  end

  # Minimal `where(...).update_all(attrs)`: writes directly, without
  # validations or callbacks, like ActiveRecord.
  class ShimRelation
    def initialize(model, conditions)
      @model = model
      @conditions = conditions
    end

    def to_a
      @model.to_adapter.find_all(@conditions)
    end

    def update_all(attributes)
      to_a.each do |record|
        attributes.each { |name, value| record.public_send("#{name}=", value) }
        record.save(validate: false)
      end
    end
  end
end
