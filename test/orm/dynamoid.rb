# frozen_string_literal: true

require "dynamoid/version"

Dynamoid.configure do |config|
  config.namespace = "devise_dynamoid_test"
  config.endpoint = ENV.fetch("DYNAMODB_ENDPOINT", "http://localhost:8000")
  config.region = ENV.fetch("AWS_REGION", "us-east-1")
  config.access_key = ENV.fetch("AWS_ACCESS_KEY_ID", "test")
  config.secret_key = ENV.fetch("AWS_SECRET_ACCESS_KEY", "test")
  config.warn_on_scan = false
  config.logger = nil
end

DYNAMOID_TEST_MODELS = %w[Admin User UserOnEngine UserOnMainApp UserWithoutEmail UserWithValidations].freeze

# Match the AR/Mongoid test setup (include_root_in_json = true).
DYNAMOID_TEST_MODELS.each { |name| name.constantize.include_root_in_json = true }

class ActiveSupport::TestCase
  setup do
    DYNAMOID_TEST_MODELS.each do |name|
      model = name.constantize
      model.create_table(sync: true) unless Dynamoid.adapter.list_tables.include?(model.table_name)
      Dynamoid.adapter.truncate(model.table_name)
    end
  end
end
