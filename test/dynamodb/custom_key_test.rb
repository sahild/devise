# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  # A Devise model whose partition key is not called `id`.
  class DynamodbCustomKeyTest < ActiveSupport::TestCase
    MODEL = if DEVISE_ORM == :dynamoid
      Class.new do
        include Dynamoid::Document
        def self.name; "CustomKeyAccount"; end
        table name: :custom_key_accounts, key: :account_id, capacity_mode: :on_demand
        field :email, :string, default: ""
        field :encrypted_password, :string, default: ""
        field :failed_attempts, :integer, default: 0
        field :unlock_token, :string
        field :locked_at, :datetime
        devise :database_authenticatable, :validatable, :lockable
      end
    else
      Class.new do
        include Aws::Record
        def self.name; "CustomKeyAccount"; end
        set_table_name "#{Shim.table_prefix}custom_key_accounts"
        string_attr :account_id, hash_key: true
        string_attr :email
        string_attr :encrypted_password
        integer_attr :failed_attempts, default_value: 0
        string_attr :unlock_token
        time_attr :locked_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
        devise :database_authenticatable, :validatable, :lockable
      end
    end

    # The table is created when this file loads, alongside the suite's other
    # tables, so table-level tests see a consistent state in any test order.
    Devise::Orm::Dynamodb::Tables.create([MODEL])
    Minitest.after_run { Devise::Orm::Dynamodb::Tables.drop([MODEL]) }

    setup do
      Devise::Orm::Dynamodb::Tables.truncate([MODEL])
    end

    def create_account
      MODEL.create!(email: generate_unique_email, password: "12345678", password_confirmation: "12345678")
    end

    test "id reads the partition key" do
      account = create_account
      assert account.account_id.present?
      assert_equal account.account_id, account.id
      assert_equal [account.account_id], account.to_key
    end

    test "lookups by id and by partition key name" do
      account = create_account
      assert_equal account, MODEL.to_adapter.get(account.id)
      assert_equal account, MODEL.to_adapter.find_first(id: account.id)
      assert_equal account, MODEL.to_adapter.find_first(account_id: account.account_id)
    end

    test "session serialization round trip" do
      account = create_account
      key, salt = MODEL.serialize_into_session(account)
      assert_equal account, MODEL.serialize_from_session(key, salt)
    end

    test "lockable increments failed attempts by partition key" do
      account = create_account
      account.valid_for_authentication? { false }
      assert_equal 1, MODEL.to_adapter.get(account.id).failed_attempts
    end

    test "uniqueness is checked against other records" do
      account = create_account
      duplicate = MODEL.new(email: account.email, password: "12345678")
      assert duplicate.invalid?
      assert_equal ["has already been taken"], duplicate.errors[:email]
      assert account.valid?
    end
  end
end
