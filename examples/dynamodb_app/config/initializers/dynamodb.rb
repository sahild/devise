# Connection settings for both DynamoDB libraries. By default the app talks to
# DynamoDB Local (docker run -p 8000:8000 amazon/dynamodb-local). Set
# DYNAMODB_ENDPOINT="" to use real AWS with your usual AWS credentials.
endpoint = ENV.fetch("DYNAMODB_ENDPOINT", "http://localhost:8000").presence
region = ENV.fetch("AWS_REGION", "us-east-1")
local_credentials = endpoint && !ENV["AWS_ACCESS_KEY_ID"]

Dynamoid.configure do |config|
  config.namespace = "devise_sample_#{Rails.env}"
  config.region = region
  config.endpoint = endpoint if endpoint
  if local_credentials
    config.access_key = "local"
    config.secret_key = "local"
  end
  config.warn_on_scan = false
end

aws_options = { region: region }
aws_options[:endpoint] = endpoint if endpoint
aws_options[:credentials] = Aws::Credentials.new("local", "local") if local_credentials
Aws.config.update(aws_options)
