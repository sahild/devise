# frozen_string_literal: true

require "test_helper"

if DEVISE_ORM == :aws_record
  require "devise/orm/dynamodb"

  # Models used by tests that need a table without a GSI, or extra fields.
  class AwsRecordAdapterPlain
    include Devise::Orm::AwsRecordSupport

    set_table_name "devise_aws_record_test_adapter_plain"
    string_attr :email
    string_attr :account_id
    string_attr :name
    integer_attr :age
  end

  class AwsRecordAdapterCaseInsensitive
    include Devise::Orm::AwsRecordSupport

    set_table_name "devise_aws_record_test_adapter_case_insensitive"
    string_attr :email
    validates_uniqueness_of :email, case_sensitive: false, allow_blank: true
  end

  class AwsRecordAdapterCaseSensitive
    include Devise::Orm::AwsRecordSupport

    set_table_name "devise_aws_record_test_adapter_case_sensitive"
    string_attr :email
    validates_uniqueness_of :email, allow_blank: true
  end

  class AwsRecordAdapterScoped
    include Devise::Orm::AwsRecordSupport

    set_table_name "devise_aws_record_test_adapter_scoped"
    string_attr :email
    string_attr :account_id
    validates_uniqueness_of :email, scope: :account_id
  end

  class AwsRecordAdapterCallbacks
    include Devise::Orm::AwsRecordSupport

    set_table_name "devise_aws_record_test_adapter_callbacks"
    string_attr :email
    string_attr :name
    include Devise::Orm # what `devise` does: adds DirtyTrackingDynamodbMethods

    attr_reader :calls, :captured
    validates :name, presence: true, if: -> { name == "" }

    before_validation { log :before_validation }
    after_validation  { log :after_validation }
    before_save       { log :before_save }
    after_save        { log :after_save }
    before_create     { log :before_create }
    after_create      { log :after_create }
    before_update     { log :before_update }
    after_update do
      log :after_update
      @captured = [devise_saved_change_to_email?, devise_email_before_last_save, devise_email_in_database]
    end

    def log(name)
      (@calls ||= []) << name
    end
  end

  class AwsRecordAdapterTest < ActiveSupport::TestCase
    EXTRA_MODELS = [AwsRecordAdapterPlain, AwsRecordAdapterCaseInsensitive, AwsRecordAdapterCaseSensitive,
                    AwsRecordAdapterScoped, AwsRecordAdapterCallbacks].freeze

    setup do
      EXTRA_MODELS.each do |model|
        model.devise_create_table!
        model.devise_delete_all!
      end
    end

    def adapter
      AwsRecordAdapterPlain.to_adapter
    end

    # OrmAdapter

    test "column_names lists the model attributes as strings" do
      assert_equal %w(account_id age email id name).sort, adapter.column_names.sort
    end

    test "get finds a record by to_key array and by scalar id" do
      user = create_user
      assert_equal user, User.to_adapter.get(user.to_key)
      assert_equal user, User.to_adapter.get(user.id)
    end

    test "get returns nil for missing, nil and blank ids" do
      assert_nil User.to_adapter.get("missing")
      assert_nil User.to_adapter.get(nil)
      assert_nil User.to_adapter.get("")
      assert_nil User.to_adapter.get([nil])
    end

    test "get! raises for a missing id" do
      assert_raise(Aws::Record::Errors::NotFound) { User.to_adapter.get!("missing") }
    end

    test "find_first by email uses the GSI" do
      user = create_user
      User.expects(:scan).never
      assert_equal user, User.to_adapter.find_first(email: user.email)
    end

    test "find_first accepts conditions with indifferent access" do
      user = create_user
      conditions = ActiveSupport::HashWithIndifferentAccess.new("email" => user.email)
      assert_equal user, User.to_adapter.find_first(conditions)
    end

    test "find_first by a non-indexed attribute scans" do
      AwsRecordAdapterPlain.create!(name: "a")
      bob = AwsRecordAdapterPlain.create!(name: "bob")
      assert_equal bob, adapter.find_first(name: "bob")
      assert_nil adapter.find_first(name: "nobody")
    end

    test "find_first with a nil condition matches records where the attribute is unset" do
      AwsRecordAdapterPlain.create!(name: "set", account_id: "1")
      unset = AwsRecordAdapterPlain.create!(name: "unset")
      assert_equal unset, adapter.find_first(account_id: nil)
    end

    test "find_first with a nil condition on a GSI attribute does not query the index" do
      user = create_user
      User.to_adapter.get(user.id).tap { |u| u.email = nil; u.save(validate: false) }
      assert_equal user, User.to_adapter.find_first(email: nil)
    end

    test "find_all orders, limits and offsets" do
      [30, 10, 20].each { |age| AwsRecordAdapterPlain.create!(age: age) }
      assert_equal [10, 20, 30], adapter.find_all(order: :age).map(&:age)
      assert_equal [30, 20, 10], adapter.find_all(order: [:age, :desc]).map(&:age)
      assert_equal [20], adapter.find_all(order: :age, limit: 1, offset: 1).map(&:age)
    end

    test "create! persists and destroy removes a record" do
      record = adapter.create!(name: "x")
      assert record.persisted?
      assert_equal record, adapter.get(record.id)

      adapter.destroy(record)
      assert_nil adapter.get(record.id)
    end

    test "destroy ignores objects of another class" do
      user = create_user
      assert_nil adapter.destroy(user)
      assert User.to_adapter.get(user.id)
    end

    # Persistence and callbacks

    test "save assigns a uuid id and timestamps" do
      user = create_user
      assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, user.id)
      assert_kind_of Time, user.created_at
      assert_kind_of Time, user.updated_at
    end

    test "create runs validation, save and create callbacks in ActiveRecord order" do
      record = AwsRecordAdapterCallbacks.create!(name: "x")
      assert_equal %i(before_validation after_validation before_save before_create after_create after_save), record.calls
    end

    test "update runs update callbacks" do
      record = AwsRecordAdapterCallbacks.create!(name: "x")
      record.calls.clear
      record.update(name: "y")
      assert_equal %i(before_validation after_validation before_save before_update after_update after_save), record.calls
    end

    test "save returns false on invalid records and save(validate: false) skips validations" do
      record = AwsRecordAdapterCallbacks.new(name: "")
      assert_not record.save
      assert_not record.persisted?

      assert record.save(validate: false)
      assert record.persisted?
    end

    test "update_attribute saves without validations" do
      user = create_user
      user.update_attribute(:username, "changed")
      assert_equal "changed", User.to_adapter.get(user.id).username
    end

    test "reload discards in-memory changes" do
      user = create_user
      user.username = "dirty"
      user.reload
      assert_equal "usertest", user.username
    end

    test "increment_counter is atomic across stale in-memory copies" do
      user = create_user
      copy = User.to_adapter.get(user.id)

      assert User.increment_counter(:failed_attempts, user.id)
      assert User.increment_counter(:failed_attempts, copy.id)
      assert_equal 2, user.reload.failed_attempts
    end

    test "increment_counter does not create missing items" do
      assert_not User.increment_counter(:failed_attempts, "missing")
      assert_nil User.to_adapter.get("missing")
    end

    test "devise_create_table! is idempotent" do
      assert_nothing_raised { 2.times { AwsRecordAdapterPlain.devise_create_table! } }
      assert AwsRecordAdapterPlain.table_exists?
    end

    test "records are equal by class and id" do
      user = create_user
      assert_equal user, User.to_adapter.get(user.id)
      assert_not_equal user, create_user
      assert_not_equal User.new, User.new
    end

    test "attribute predicates are defined like ActiveRecord" do
      admin = create_admin
      assert_not admin.unconfirmed_email?
      admin.unconfirmed_email = "new@example.com"
      assert admin.unconfirmed_email?
      assert admin.respond_to?(:unconfirmed_email?)
      assert_not admin.respond_to?(:unknown_attr?)
    end

    test "[] returns nil for unknown attributes" do
      assert_nil User.new[:fake_key]
    end

    test "serializable_hash includes nil attributes and hides unsafe ones" do
      hash = create_user.serializable_hash
      assert hash.key?("facebook_token")
      assert_not hash.key?("encrypted_password")
    end

    # Dirty tracking primitives

    test "devise_will_save_change_to_email? and devise_email_in_database reflect a pending change" do
      user = create_user
      original = user.email
      assert_not user.devise_will_save_change_to_email?

      user.email = "changed@example.com"
      assert user.devise_will_save_change_to_email?
      assert_equal original, user.devise_email_in_database
    end

    test "saved change and value before last save after save returns" do
      user = create_user
      original = user.email
      user.email = "changed@example.com"
      user.save!

      assert user.devise_saved_change_to_email?
      assert_equal original, user.devise_email_before_last_save

      user.username = "other"
      user.save!
      assert_not user.devise_saved_change_to_email?
      assert_equal "changed@example.com", user.devise_email_before_last_save
    end

    test "dirty values are correct inside after_update" do
      record = AwsRecordAdapterCallbacks.create!(name: "x", email: "old@example.com")
      record.update(email: "new@example.com")
      # As in ActiveRecord: the write has happened, so the database value is the new one.
      assert_equal [true, "old@example.com", "new@example.com"], record.captured
    end

    test "devise_saved_change_to_encrypted_password? after a password change" do
      user = create_user
      user.update(password: "newpassword", password_confirmation: "newpassword")
      assert user.devise_saved_change_to_encrypted_password?

      user.update(username: "x")
      assert_not user.devise_saved_change_to_encrypted_password?
    end

    test "devise_unconfirmed_email_will_change! forces an unchanged value to be written" do
      admin = create_admin
      admin.update_attribute(:unconfirmed_email, "model@example.com")
      Admin.where(id: admin.id).update_all(unconfirmed_email: "db@example.com")

      admin.devise_unconfirmed_email_will_change!
      admin.save(validate: false)
      assert_equal "model@example.com", Admin.to_adapter.get(admin.id).unconfirmed_email
    end

    test "devise_respond_to_and_will_save_change_to_attribute? handles symbols, unknowns and arrays" do
      user = create_user
      user.username = "changed"
      assert user.devise_respond_to_and_will_save_change_to_attribute?(:username)
      assert_not user.devise_respond_to_and_will_save_change_to_attribute?(:email)
      assert_not user.devise_respond_to_and_will_save_change_to_attribute?(:unknown)
      assert_not user.devise_respond_to_and_will_save_change_to_attribute?([:email, false])
    end

    # Uniqueness

    test "duplicate email on User is rejected with the taken message" do
      user = create_user
      duplicate = new_user(email: user.email)
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:email], "has already been taken"
    end

    test "re-saving the same record is valid" do
      user = create_user
      assert user.valid?
    end

    test "blank values are allowed" do
      2.times { assert AwsRecordAdapterCaseSensitive.create(email: "").persisted? }
    end

    test "case_sensitive (default) allows values differing only by case" do
      AwsRecordAdapterCaseSensitive.create!(email: "A@x.com")
      assert AwsRecordAdapterCaseSensitive.new(email: "a@x.com").valid?
      assert_not AwsRecordAdapterCaseSensitive.new(email: "A@x.com").valid?
    end

    test "case_sensitive: false rejects values differing only by case" do
      AwsRecordAdapterCaseInsensitive.create!(email: "A@x.com")
      assert_not AwsRecordAdapterCaseInsensitive.new(email: "a@x.com").valid?
    end

    test "scope allows duplicates across different scope values" do
      AwsRecordAdapterScoped.create!(email: "a@x.com", account_id: "1")
      assert AwsRecordAdapterScoped.new(email: "a@x.com", account_id: "2").valid?
      assert_not AwsRecordAdapterScoped.new(email: "a@x.com", account_id: "1").valid?
    end

    # ORM detection and dispatch

    test "Devise::Orm.dynamodb? recognises aws-record models" do
      assert Devise::Orm.dynamodb?(User)
      assert_not Devise::Orm.dynamodb?(Class.new)
      assert_includes User.ancestors, Devise::Orm::DirtyTrackingDynamodbMethods
    end

    test "library_path maps library names to adapters" do
      assert_equal "devise/orm/dynamoid", Devise::Orm::Dynamodb.library_path(:dynamoid)
      assert_equal "devise/orm/aws_record", Devise::Orm::Dynamodb.library_path(:aws_record)
      assert_equal "devise/orm/aws_record", Devise::Orm::Dynamodb.library_path("aws-record")
      assert_raise(ArgumentError) { Devise::Orm::Dynamodb.library_path(:mongoid) }
    end
  end
end
