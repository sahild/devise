# frozen_string_literal: true

require "test_helper"
require "stringio"
require "rake"
require "devise/orm/dynamodb/tasks"

class DynamodbTasksTest < ActiveSupport::TestCase
  class FakeModel
    attr_reader :table_name, :created_with, :deleted

    def initialize(table_name)
      @table_name = table_name
      @created_with = nil
      @deleted = false
    end

    def create_table(options)
      @created_with = options
    end

    def delete_table
      @deleted = true
    end
  end

  class FakeAdapter
    attr_accessor :tables, :error

    def initialize(tables: [], error: nil)
      @tables = tables
      @error = error
    end

    def list_tables
      raise error if error

      tables
    end
  end

  setup do
    @output = StringIO.new
  end

  def tasks(classes, adapter)
    Devise::Orm::Dynamodb::Tasks.new(classes, output: @output, dynamoid_adapter: adapter)
  end

  test "create_tables creates a missing dynamoid table" do
    model = FakeModel.new("devise_dynamoid_test_users")

    tasks([model], FakeAdapter.new(tables: [])).create_tables

    assert_equal({ sync: true }, model.created_with)
    assert_match(/devise_dynamoid_test_users created/, @output.string)
  end

  test "create_tables reports an existing dynamoid table without creating it" do
    model = FakeModel.new("devise_dynamoid_test_users")

    tasks([model], FakeAdapter.new(tables: ["devise_dynamoid_test_users"])).create_tables

    assert_nil model.created_with
    assert_match(/devise_dynamoid_test_users already exists/, @output.string)
  end

  test "drop_tables refuses in production without FORCE" do
    model = FakeModel.new("devise_dynamoid_test_users")

    error = assert_raises(RuntimeError) do
      tasks([model], FakeAdapter.new).drop_tables(env: "production", force: false)
    end

    assert_match(/Refusing to drop DynamoDB tables in production/, error.message)
    refute model.deleted
  end

  test "drop_tables runs in production with FORCE" do
    model = FakeModel.new("devise_dynamoid_test_users")

    tasks([model], FakeAdapter.new(tables: ["devise_dynamoid_test_users"])).drop_tables(env: "production", force: true)

    assert model.deleted
    assert_match(/devise_dynamoid_test_users dropped/, @output.string)
  end

  test "drop_tables deletes an existing table outside production" do
    model = FakeModel.new("devise_dynamoid_test_users")

    tasks([model], FakeAdapter.new(tables: ["devise_dynamoid_test_users"])).drop_tables(env: "development", force: false)

    assert model.deleted
    assert_match(/devise_dynamoid_test_users dropped/, @output.string)
  end

  test "drop_tables skips a missing table" do
    model = FakeModel.new("devise_dynamoid_test_users")

    tasks([model], FakeAdapter.new(tables: [])).drop_tables(env: "development", force: false)

    refute model.deleted
    assert_match(/devise_dynamoid_test_users does not exist/, @output.string)
  end

  test "ping reports success when the adapter lists tables" do
    assert tasks([], FakeAdapter.new).ping
    assert_match(/DynamoDB is reachable/, @output.string)
  end

  test "ping reports failure with the error message" do
    refute tasks([], FakeAdapter.new(error: StandardError.new("connection refused"))).ping
    assert_match(/DynamoDB is not reachable: connection refused/, @output.string)
  end

  test "dynamodb_classes selects only DynamoDB models from mappings" do
    plain_class = Class.new
    dynamo_class =
      case DEVISE_ORM
      when :dynamoid then Class.new { include Dynamoid::Document }
      when :aws_record then Class.new { include Aws::Record }
      end

    mappings = { one: stub(to: plain_class), two: stub(to: User), three: stub(to: nil) }
    mappings.update(four: stub(to: dynamo_class), five: stub(to: dynamo_class)) if dynamo_class

    expected = dynamo_class ? [User, dynamo_class] : []
    assert_equal expected, Devise::Orm::Dynamodb::Tasks.dynamodb_classes(mappings)
  end
end

class DynamodbRakeTasksTest < ActiveSupport::TestCase
  setup do
    @previous_app = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path("../../../lib/tasks/devise_dynamodb.rake", __FILE__)
  end

  teardown do
    Rake.application = @previous_app
  end

  test "defines the devise dynamodb tasks" do
    %w(devise:dynamodb:create_tables devise:dynamodb:drop_tables devise:dynamodb:ping).each do |name|
      assert Rake::Task.task_defined?(name), "expected rake task #{name} to be defined"
    end
  end
end
