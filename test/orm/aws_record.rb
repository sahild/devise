# frozen_string_literal: true

require "aws-record"

# Points the aws-sdk at the DynamoDB Local instance used by the test suite.
ENV["AWS_ENDPOINT_URL_DYNAMODB"] ||= ENV.fetch("DYNAMODB_ENDPOINT", "http://localhost:8000")
ENV["AWS_REGION"] ||= "us-east-1"
ENV["AWS_ACCESS_KEY_ID"] ||= "fakeKey"
ENV["AWS_SECRET_ACCESS_KEY"] ||= "fakeSecret"

module DeviseAwsRecordTestTables
  # Every table used by the aws-record test models. Only these are touched.
  MODELS = %w[User Admin UserOnEngine UserOnMainApp UserWithoutEmail UserWithValidations].freeze

  def self.models
    MODELS.map { |name| Object.const_get(name) }
  end

  def self.create_missing!
    models.each(&:devise_create_table!)
  end

  def self.reset!
    create_missing!
    models.each(&:devise_delete_all!)
  end
end

DeviseAwsRecordTestTables.create_missing!

# Match the AR/Mongoid test setup (include_root_in_json = true).
DeviseAwsRecordTestTables.models.each { |model| model.include_root_in_json = true }

class ActiveSupport::TestCase
  setup do
    DeviseAwsRecordTestTables.reset!
  end
end
