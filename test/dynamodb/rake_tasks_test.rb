# frozen_string_literal: true

require "test_helper"
require "rake"

class DynamodbRakeTasksTest < ActiveSupport::TestCase
  setup do
    # Like `rake -T`, keep task descriptions so they can be asserted on.
    @record_task_metadata = Rake::TaskManager.record_task_metadata
    Rake::TaskManager.record_task_metadata = true
    @rake = Rake::Application.new
    Rake.application = @rake
    Rake::Task.define_task(:environment)
    load File.expand_path("../../lib/devise/orm/dynamodb/tasks/dynamodb.rake", __dir__)
  end

  teardown do
    Rake::TaskManager.record_task_metadata = @record_task_metadata
    Rake.application = Rake::Application.new
  end

  def run_task(name)
    capture_io { @rake[name].invoke }.first
  end

  test "defines the devise:dynamodb tasks with descriptions" do
    %w(devise:dynamodb:create devise:dynamodb:drop devise:dynamodb:status).each do |name|
      assert @rake.lookup(name), "expected #{name} to be defined"
      assert @rake.lookup(name).comment.present?, "expected #{name} to have a description"
    end
  end

  test "the Devise engine registers the tasks" do
    Rails.application.load_tasks
    assert Rake::Task.task_defined?("devise:dynamodb:create")
  end

  if Devise::Test.dynamodb?
    test "status lists every Devise table" do
      output = run_task("devise:dynamodb:status")
      assert_match(/User: table #{Regexp.escape(Devise::Orm::Dynamodb::Tables.table_name(User))} \(exists\)/, output)
      assert_match(/Admin: table/, output)
    end

    test "create reports existing tables" do
      assert_match(/already exist/, run_task("devise:dynamodb:create"))
    end

    test "drop and create recreate the tables" do
      tables = Devise::Orm::Dynamodb::Tables
      model = throwaway_model
      tables.stubs(:models).returns([model])

      assert_match(/Created table .* \(RakeTasksThrowaway\)/, run_task("devise:dynamodb:create"))
      assert tables.exists?(model)

      assert_match(/Dropped table .* \(RakeTasksThrowaway\)/, run_task("devise:dynamodb:drop"))
      assert_not tables.exists?(model)
    ensure
      tables.unstub(:models)
      if model
        tables.drop([model])
        Devise::Orm::Dynamodb.unregister(model)
      end
    end

    test "drop refuses to run in production" do
      Rails.env.stubs(:production?).returns(true)
      error = assert_raise(SystemExit) { capture_io { @rake["devise:dynamodb:drop"].invoke } }
      assert_not error.success?
      assert Devise::Orm::Dynamodb::Tables.exists?(User)
    end
  else
    test "tasks explain how to enable DynamoDB" do
      error = assert_raise(SystemExit) { capture_io { @rake["devise:dynamodb:status"].invoke } }
      assert_not error.success?
    end
  end

  private

  # A Devise model with its own table, so dropping it does not affect the
  # tables shared by the rest of the suite.
  def throwaway_model
    if DEVISE_ORM == :dynamoid
      Class.new do
        include Dynamoid::Document
        def self.name; "RakeTasksThrowaway"; end
        table name: :rake_tasks_throwaway, capacity_mode: :on_demand
        field :email, :string
        field :encrypted_password, :string
        devise :database_authenticatable
      end
    else
      Class.new do
        include Aws::Record
        def self.name; "RakeTasksThrowaway"; end
        set_table_name "#{Shim.table_prefix}rake_tasks_throwaway"
        string_attr :id, hash_key: true
        string_attr :email
        string_attr :encrypted_password
        devise :database_authenticatable
      end
    end
  end
end
