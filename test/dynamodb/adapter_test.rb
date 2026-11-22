# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  class DynamodbAdapterTest < ActiveSupport::TestCase
    def adapter
      User.to_adapter
    end

    test "uses the DynamoDB adapter" do
      assert_kind_of Devise::Orm::Dynamodb::Adapter, adapter
      assert_kind_of Devise::Orm::Dynamodb::Adapter, Admin.to_adapter
    end

    test "column_names lists the declared attributes" do
      assert_includes adapter.column_names, "email"
      assert_includes adapter.column_names, "encrypted_password"
      assert_includes adapter.column_names, "id"
    end

    test "get returns the record by partition key, accepting to_key arrays" do
      user = create_user
      assert_equal user, adapter.get(user.id)
      assert_equal user, adapter.get([user.id])
    end

    test "get returns nil for missing or blank keys" do
      assert_nil adapter.get("does-not-exist")
      assert_nil adapter.get(nil)
      assert_nil adapter.get("")
      assert_nil adapter.get([])
    end

    test "get! raises for missing records" do
      assert_raise(StandardError) { adapter.get!("does-not-exist") }
    end

    test "find_first by partition key" do
      user = create_user
      assert_equal user, adapter.find_first(id: user.id)
      assert_nil adapter.find_first(id: user.id, email: "other@example.com")
    end

    test "find_first through a global secondary index" do
      user = create_user
      create_user
      Devise::Orm::Dynamodb.expects(:warn_scan).never
      assert_equal user, adapter.find_first(email: user.email)
    end

    test "find_first with an indexed and a non-indexed condition rechecks every condition" do
      user = create_user(username: "alice")
      assert_equal user, adapter.find_first(email: user.email, username: "alice")
      assert_nil adapter.find_first(email: user.email, username: "bob")
    end

    test "find_first falls back to a scan for non-indexed attributes" do
      user = create_user
      user.update_attribute(:unlock_token, "abc")
      Devise::Orm::Dynamodb.expects(:warn_scan).with(User, [:unlock_token]).once
      assert_equal user, adapter.find_first(unlock_token: "abc")
    end

    test "find_first returns nil when nothing matches" do
      create_user
      assert_nil adapter.find_first(email: "nobody@example.com")
      assert_nil adapter.find_first(reset_password_token: "nope")
    end

    test "find_first sees writes immediately (strongly consistent reads)" do
      user = create_user
      user.update_attribute(:reset_password_token, "fresh-token")
      assert_equal user, adapter.find_first(reset_password_token: "fresh-token")

      user.update_attribute(:email, "changed@example.com")
      assert_equal user, adapter.find_first(email: "changed@example.com")
    end

    test "string conditions match non-string attributes by their string form" do
      user = create_user
      user.update_attribute(:sign_in_count, 3)
      assert_equal user, adapter.find_first(id: user.id, sign_in_count: "3")
      assert_nil adapter.find_first(id: user.id, sign_in_count: "4")
    end

    test "non-string conditions match string attributes by their string form" do
      user = create_user
      user.update_attribute(:username, "42")
      assert_equal user, adapter.find_first(id: user.id, username: 42)
    end

    test "empty string and nil conditions are equivalent" do
      user = create_user
      assert_equal user, adapter.find_first(id: user.id, unlock_token: nil)
      assert_equal user, adapter.find_first(id: user.id, unlock_token: "")
    end

    test "id conditions are mapped to the partition key" do
      user = create_user
      assert_equal user, adapter.find_first("id" => user.id)
    end

    test "unknown attributes raise a descriptive error" do
      error = assert_raise(Devise::Orm::Dynamodb::UnknownAttributeError) do
        adapter.find_first(not_an_attribute: "x")
      end
      assert_match(/no attribute :not_an_attribute/, error.message)
    end

    test "find_all with order, limit and offset" do
      users = %w(b c a).map { |name| create_user(username: name) }
      ordered = adapter.find_all(order: [:username, :asc])
      assert_equal %w(a b c), ordered.map(&:username)

      assert_equal %w(c b), adapter.find_all(order: [:username, :desc], limit: 2).map(&:username)
      assert_equal %w(b c), adapter.find_all(order: [:username, :asc], offset: 1).map(&:username)
      assert_equal users.size, adapter.find_all.size
    end

    test "find_first honours order" do
      %w(m z a).each { |name| create_user(username: name) }
      assert_equal "z", adapter.find_first(order: [:username, :desc]).username
    end

    test "create! and destroy" do
      user = adapter.create!(valid_attributes)
      assert user.persisted?
      assert_equal user, adapter.get(user.id)

      adapter.destroy(user)
      assert_nil adapter.get(user.id)
    end

    test "destroy ignores objects of other classes" do
      admin = create_admin
      assert_nil adapter.destroy(admin)
      assert_equal admin, Admin.to_adapter.get(admin.id)
    end

    test "logs a scan warning only once per model and set of keys" do
      logger = mock
      logger.expects(:warn).once
      previous = Devise::Orm::Dynamodb.instance_variable_get(:@logger)
      Devise::Orm::Dynamodb.logger = logger
      Devise::Orm::Dynamodb.instance_variable_get(:@scan_warnings).clear

      2.times { adapter.find_first(last_sign_in_ip: "127.0.0.1") }
    ensure
      Devise::Orm::Dynamodb.logger = previous
    end
  end
end
