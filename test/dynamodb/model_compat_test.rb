# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  class DynamodbModelCompatTest < ActiveSupport::TestCase
    test "models are detected as DynamoDB models" do
      assert Devise::Orm.dynamodb?(User)
      assert_not Devise::Orm.active_record?(User)
      assert_includes Devise::Orm::Dynamodb.models, User
      assert_includes Devise::Orm::Dynamodb.models, Admin
    end

    test "the selected library matches the models" do
      assert_equal DEVISE_ORM, Devise::Orm::Dynamodb.library
      assert_equal DEVISE_ORM == :dynamoid, Devise::Orm.dynamoid?(User)
      assert_equal DEVISE_ORM == :aws_record, Devise::Orm.aws_record?(User)
    end

    test "create generates a partition key and timestamps" do
      user = create_user
      assert user.id.present?
      assert user.created_at.present?
      assert user.updated_at.present?
    end

    test "update with an attributes hash assigns and saves" do
      user = create_user
      assert user.update(username: "changed")
      assert_equal "changed", User.to_adapter.get(user.id).username
    end

    test "update returns false and does not save when invalid" do
      user = create_user
      assert_not user.update(email: "invalid")
      assert_not_equal "invalid", User.to_adapter.get(user.id).email
    end

    test "update_attribute skips validations" do
      user = create_user
      user.update_attribute(:email, "invalid")
      assert_equal "invalid", User.to_adapter.get(user.id).email
    end

    test "reload reads the latest values" do
      user = create_user
      User.to_adapter.get(user.id).update_attribute(:username, "elsewhere")
      assert_equal "elsewhere", user.reload.username
    end

    test "increment_counter increments atomically" do
      user = create_user
      User.increment_counter(:failed_attempts, user.id)
      User.increment_counter(:failed_attempts, user.id)
      assert_equal 2, user.reload.failed_attempts
    end

    test "dirty tracking helpers before and after save" do
      user = create_user
      assert_not user.devise_will_save_change_to_email?

      original = user.email
      user.email = "new@example.com"
      assert user.devise_will_save_change_to_email?
      assert_equal original, user.devise_email_in_database

      user.save!
      assert_not user.devise_will_save_change_to_email?
      assert user.devise_saved_change_to_email?
      assert_equal original, user.devise_email_before_last_save
    end

    test "assigning the same value is not a pending change" do
      user = create_user
      user.email = user.email.dup
      assert_not user.devise_will_save_change_to_email?
    end

    test "password changes are tracked as saved changes" do
      user = create_user
      user.password = user.password_confirmation = "another-password"
      user.save!
      assert user.devise_saved_change_to_encrypted_password?
    end

    test "devise_unconfirmed_email_will_change! forces the attribute into the next write" do
      admin = create_admin
      admin.update_attribute(:unconfirmed_email, "mine@example.com")
      stale = Admin.to_adapter.get(admin.id)
      Admin.where(id: admin.id).update_all(unconfirmed_email: "victim@example.com")

      stale.send(:devise_unconfirmed_email_will_change!)
      stale.save(validate: false)
      assert_equal "mine@example.com", Admin.to_adapter.get(admin.id).unconfirmed_email
    end

    test "devise_respond_to_and_will_save_change_to_attribute?" do
      user = create_user
      assert_not user.devise_respond_to_and_will_save_change_to_attribute?(:encrypted_password)
      user.password = "new-password-123"
      assert user.devise_respond_to_and_will_save_change_to_attribute?(:encrypted_password)
      assert_not user.devise_respond_to_and_will_save_change_to_attribute?(:not_an_attribute)
    end

    test "serialization hides Devise's unsafe attributes and includes declared ones" do
      user = create_user
      json = ActiveSupport::JSON.decode(user.to_json)["user"]
      assert json.key?("email")
      assert json.key?("facebook_token")
      assert_not json.key?("encrypted_password")
      assert_not json.key?("confirmation_token")
    end

    test "records are equal by partition key" do
      user = create_user
      assert_equal user, User.to_adapter.get(user.id)
      assert_not_equal user, create_user
    end

    test "to_key and to_param use the partition key" do
      user = create_user
      assert_equal [user.id], user.to_key
      assert_equal user.id, user.to_param
    end

    test "saving a record deleted in the meantime does not recreate it" do
      user = create_user
      stale = User.to_adapter.get(user.id)
      user.destroy

      stale.sign_in_count = 5
      assert_not stale.save(validate: false)
      assert_nil User.to_adapter.get(user.id)
    end

    test "destroy returns false when a callback halts it" do
      klass = Class.new(User) do
        def self.name; "UndeletableUser"; end
        before_destroy { throw :abort }
      end
      record = klass.create!(valid_attributes)
      assert_equal false, record.destroy
      assert User.to_adapter.get(record.id)
    ensure
      Devise::Orm::Dynamodb.unregister(klass) if klass
    end
  end
end

