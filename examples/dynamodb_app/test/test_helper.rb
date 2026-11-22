ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Creates the users table if needed (bin/rails devise:dynamodb:create_tables
# does the same) and empties it before each test.
module DynamodbTestHelper
  def self.reset!
    Devise::Orm::Dynamodb::Tasks.new([User], output: StringIO.new).create_tables
    if DYNAMODB_LIBRARY == :aws_record
      User.devise_delete_all!
    else
      Dynamoid.adapter.truncate(User.table_name)
    end
  end
end

class ActiveSupport::TestCase
  setup { DynamodbTestHelper.reset! }
end
