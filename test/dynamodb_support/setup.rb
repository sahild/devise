# frozen_string_literal: true

# Shared setup for DEVISE_ORM=dynamoid and DEVISE_ORM=aws_record.
#
# The suite talks to a real DynamoDB engine, by default DynamoDB Local on
# http://localhost:8000 (override with DYNAMODB_ENDPOINT, see the test app's
# config/initializers/dynamodb.rb). Tables use a per-run name prefix, are
# created once and emptied before each test.
module DevisePrepareDynamodb
  def self.models
    Devise::Orm::Dynamodb::Tables.models
  end

  def self.prepare!
    Devise::Orm::Dynamodb.logger = Logger.new(nil)
    models.each { |model| model.include_root_in_json = true }
    tables = Devise::Orm::Dynamodb::Tables
    tables.drop(models)
    tables.create(models)
    Minitest.after_run { tables.drop(models) }
  end
end

class ActiveSupport::TestCase
  setup do
    Devise::Orm::Dynamodb::Tables.truncate(DevisePrepareDynamodb.models)
  end
end
