# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  class DynamodbTablesTest < ActiveSupport::TestCase
    def tables
      Devise::Orm::Dynamodb::Tables
    end

    test "models include every Devise DynamoDB model" do
      assert_includes tables.models, User
      assert_includes tables.models, Admin
    end

    test "models sharing a table are created once" do
      names = tables.table_models.map { |model| tables.table_name(model) }
      assert_equal names.uniq, names
      assert_includes names, tables.table_name(UserOnEngine)
      assert_equal tables.table_name(User), tables.table_name(UserOnEngine)
    end

    test "status reports existing tables and indexes" do
      row = tables.status.find { |model, *| model == "User" }
      assert row, "expected a row for User"
      _, table, exists, indexes = row
      assert_equal tables.table_name(User), table
      assert exists
      assert_equal 1, indexes.size
    end

    test "create is a no-op when tables exist" do
      assert_empty tables.create([User])
    end

    test "truncate deletes every item" do
      3.times { create_user }
      tables.truncate([User])
      assert_empty User.to_adapter.find_all
    end
  end
end
