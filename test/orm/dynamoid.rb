# frozen_string_literal: true

# Runs the suite against DynamoDB through Dynamoid. Requires DynamoDB Local
# (or another DynamoDB-compatible endpoint) on DYNAMODB_ENDPOINT (default
# http://localhost:8000). Dynamoid is configured in the test app's
# config/initializers/dynamodb.rb: index names are derived from the namespace
# when a model is defined, so it must be configured before models load.
require "dynamodb_support/setup"

DevisePrepareDynamodb.prepare!
