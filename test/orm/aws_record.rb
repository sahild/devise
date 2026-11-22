# frozen_string_literal: true

# Runs the suite against DynamoDB through aws-record. Requires DynamoDB Local
# (or another DynamoDB-compatible endpoint) on DYNAMODB_ENDPOINT (default
# http://localhost:8000). The client is configured in
# config/initializers/dynamodb.rb of the test app.
require "dynamodb_support/setup"

DevisePrepareDynamodb.prepare!
