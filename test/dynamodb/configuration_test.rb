# frozen_string_literal: true

require "test_helper"

class DynamodbConfigurationTest < ActiveSupport::TestCase
  test "dynamoid is the default DynamoDB library" do
    expected = Devise::Test.dynamodb? ? DEVISE_ORM : :dynamoid
    assert_equal expected, Devise.dynamodb_library
  end

  test "Devise::Orm.dynamodb? is false for other models" do
    model = Class.new
    assert_not Devise::Orm.dynamodb?(model)
  end

  if Devise::Test.dynamodb?
    test "unknown libraries are rejected" do
      swap Devise, dynamodb_library: :cassandra do
        error = assert_raise(ArgumentError) { Devise::Orm::Dynamodb.library }
        assert_match(/:dynamoid, :aws_record/, error.message)
      end
    end

    test "time formatter keeps microseconds" do
      time = Time.utc(2026, 1, 2, 3, 4, 5, 123456)
      assert_equal "2026-01-02T03:04:05.123456Z", Devise::Orm::Dynamodb::TimeFormatter.format(time)
    end

    test "range keys are rejected" do
      model = if DEVISE_ORM == :dynamoid
        Class.new do
          include Dynamoid::Document
          def self.name; "RangeKeyModel"; end
          range :created_on, :string
        end
      else
        Class.new do
          include Aws::Record
          def self.name; "RangeKeyModel"; end
          string_attr :id, hash_key: true
          string_attr :created_on, range_key: true
        end
      end

      assert_raise(Devise::Orm::Dynamodb::UnsupportedSchemaError) do
        Devise::Orm::Dynamodb::Adapter.new(model)
      end
    end
  end
end
