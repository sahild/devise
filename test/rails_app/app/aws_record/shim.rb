# frozen_string_literal: true

module Shim
  extend ::ActiveSupport::Concern

  # Per-run table name prefix, so test runs do not collide (Dynamoid uses its
  # namespace setting for the same purpose).
  def self.table_prefix
    "devise_test_#{Process.pid}_"
  end

  # Like an Active Record column default: new records start with an empty email
  # and password, but nil can still be assigned and read back afterwards.
  # (aws-record's `default_value:` would turn every nil back into the default.)
  def initialize(*args, &block)
    super
    self.email = "" if respond_to?(:email=) && email.nil?
    self.encrypted_password = "" if respond_to?(:encrypted_password=) && encrypted_password.nil?
  end

  class_methods do
    def devise_table(name)
      set_table_name "#{Shim.table_prefix}#{name}"
    end

    def time_field(name)
      time_attr name, formatter: Devise::Orm::Dynamodb::TimeFormatter
    end

    def find(id)
      to_adapter.get!(id)
    end

    def find_by_email(email)
      to_adapter.find_first(email: email)
    end

    def find_by(conditions)
      to_adapter.find_first(conditions)
    end

    def count
      scan(consistent_read: true).count
    end

    def destroy_all
      to_adapter.find_all.each(&:destroy)
    end

    # Minimal stand-in for Active Record's `where(...).update_all(...)`: writes
    # the attributes directly, skipping validations and callbacks.
    def where(conditions)
      model = self
      Struct.new(:ids) do
        define_method(:update_all) do |attributes|
          ids.each { |id| model.update(attributes.merge(id: id)) }
        end
      end.new(Array(conditions.fetch(:id)))
    end
  end
end
