# frozen_string_literal: true

# Connection settings for Amazon DynamoDB.
#
# In development and test this points at DynamoDB Local
# (https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html):
#
#   docker run -p 8000:8000 amazon/dynamodb-local
#
# In production leave DYNAMODB_ENDPOINT unset and use the standard AWS
# credential chain (IAM role, AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY, ...).
endpoint = ENV.fetch("DYNAMODB_ENDPOINT") { "http://localhost:8000" unless Rails.env.production? }
region = ENV.fetch("AWS_REGION", "us-east-1")
local_credentials = endpoint && ENV["AWS_ACCESS_KEY_ID"].nil?

case Devise.dynamodb_library
when :dynamoid
  # Configure before models load: Dynamoid derives table and index names
  # from the namespace when a model class is defined.
  Dynamoid.configure do |config|
    config.namespace = "devise_example_dynamoid_#{Rails.env}"
    config.region = region
    config.endpoint = endpoint if endpoint
    if local_credentials
      config.access_key = "local"
      config.secret_key = "local"
    end
    # Tables are created explicitly with `bin/rails devise:dynamodb:create`.
    config.create_table_on_save = false
  end
when :aws_record
  options = { region: region }
  options[:endpoint] = endpoint if endpoint
  options[:credentials] = Aws::Credentials.new("local", "local") if local_credentials
  Aws.config.update(options)
end
