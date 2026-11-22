# frozen_string_literal: true

# DynamoDB settings for DEVISE_ORM=dynamoid / DEVISE_ORM=aws_record. This runs
# before any model is loaded: Dynamoid derives index names from its namespace
# when a model is defined, and aws-record builds its client on first use.
if Devise::Test.dynamodb?
  endpoint = ENV["DYNAMODB_ENDPOINT"] || "http://localhost:8000"

  if DEVISE_ORM == :dynamoid
    Dynamoid.configure do |config|
      config.endpoint = endpoint
      config.region = "us-east-1"
      config.access_key = "devise"
      config.secret_key = "devise"
      config.namespace = "devise_test_#{Process.pid}"
      config.logger = Logger.new(nil)
      config.warn_on_scan = false
      config.create_table_on_save = false
    end
  else
    Aws.config.update(
      endpoint: endpoint,
      region: "us-east-1",
      credentials: Aws::Credentials.new("devise", "devise")
    )
  end
end
