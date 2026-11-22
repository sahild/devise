# frozen_string_literal: true

require "test_helper"

if DEVISE_ORM == :dynamoid
  require "devise/orm/dynamodb"

  # Models without a GSI, or with extra fields, used by tests that need them.
  # Dynamoid applies the configured namespace to their table names.
  class DynamoidAdapterPlain
    include Dynamoid::Document

    table name: :devise_dynamoid_adapter_plain
    field :email, :string
    field :account_id, :string
    field :name, :string
    field :age, :integer
  end

  class DynamoidAdapterCaseSensitive
    include Dynamoid::Document

    table name: :devise_dynamoid_adapter_case_sensitive
    field :email, :string
    validates_uniqueness_of :email, case_sensitive: true, allow_blank: true
  end

  class DynamoidAdapterCaseInsensitive
    include Dynamoid::Document

    table name: :devise_dynamoid_adapter_case_insensitive
    field :email, :string
    validates_uniqueness_of :email, case_sensitive: false, allow_blank: true
  end

  class DynamoidAdapterScoped
    include Dynamoid::Document

    table name: :devise_dynamoid_adapter_scoped
    field :email, :string
    field :account_id, :string
    validates_uniqueness_of :email, scope: :account_id
  end

  class DynamoidAdapterUnindexed
    include Dynamoid::Document

    table name: :devise_dynamoid_adapter_unindexed
    field :email, :string
    validates_uniqueness_of :email
  end

  class DynamoidAdapterCallback
    include Dynamoid::Document
    include Devise::Orm::DirtyTrackingDynamodbMethods

    table name: :devise_dynamoid_adapter_callback
    field :email, :string
    attr_reader :captured

    after_update { @captured = [devise_saved_change_to_email?, devise_email_before_last_save] }
  end

  class DynamoidAdapterNestedSave
    include Dynamoid::Document
    include Devise::Orm::DirtyTrackingDynamodbMethods

    table name: :devise_dynamoid_adapter_nested_save
    field :email, :string
    after_create :save
  end

  class DynamoidAdapterTest < ActiveSupport::TestCase
    CUSTOM_MODELS = [
      DynamoidAdapterPlain,
      DynamoidAdapterCaseSensitive,
      DynamoidAdapterCaseInsensitive,
      DynamoidAdapterScoped,
      DynamoidAdapterUnindexed,
      DynamoidAdapterCallback,
      DynamoidAdapterNestedSave
    ].freeze

    setup do
      CUSTOM_MODELS.each do |model|
        model.create_table(sync: true) unless Dynamoid.adapter.list_tables.include?(model.table_name)
        Dynamoid.adapter.truncate(model.table_name)
      end
    end

    # 1. OrmAdapter

    test "column_names lists the model attributes as strings" do
      columns = User.to_adapter.column_names

      assert_includes columns, "email"
      assert_includes columns, "encrypted_password"
      assert columns.all? { |column| column.is_a?(String) }
    end

    test "get finds a record by to_key array" do
      user = create_user

      assert_equal user.id, User.to_adapter.get(user.to_key).id
    end

    test "get finds a record by scalar id" do
      user = create_user

      assert_equal user.id, User.to_adapter.get(user.id).id
    end

    test "get returns nil for a missing id" do
      assert_nil User.to_adapter.get("does-not-exist")
    end

    test "get returns nil for nil or blank keys" do
      assert_nil User.to_adapter.get(nil)
      assert_nil User.to_adapter.get("")
    end

    test "get! raises RecordNotFound for a missing id" do
      assert_raises(Dynamoid::Errors::RecordNotFound) do
        User.to_adapter.get!("does-not-exist")
      end
    end

    test "find_first by email uses the GSI" do
      user = create_user(email: "gsi-lookup@example.com")

      found = User.to_adapter.find_first(email: "gsi-lookup@example.com")

      assert_equal user.id, found.id
    end

    test "find_first by a non-indexed attribute scans" do
      user = create_user(username: "scan-me")
      create_user(username: "someone-else")

      found = User.to_adapter.find_first(username: "scan-me")

      assert_equal user.id, found.id
    end

    test "find_first with a nil condition matches records where the attribute is unset" do
      unset = DynamoidAdapterPlain.create!(name: "unset")
      DynamoidAdapterPlain.create!(name: "set", age: 5)

      found = DynamoidAdapterPlain.to_adapter.find_all(age: nil)

      assert_equal [unset.id], found.map(&:id)
    end

    test "find_first with an empty string condition matches records where the attribute is unset" do
      unset = DynamoidAdapterPlain.create!(name: "unset")
      DynamoidAdapterPlain.create!(name: "set", email: "set@example.com")

      found = DynamoidAdapterPlain.to_adapter.find_first(email: "")

      assert_equal unset.id, found.id
    end

    test "find_all sorts ascending by default and descending on request" do
      DynamoidAdapterPlain.create!(name: "b", age: 20)
      DynamoidAdapterPlain.create!(name: "a", age: 10)
      DynamoidAdapterPlain.create!(name: "c", age: 30)
      adapter = DynamoidAdapterPlain.to_adapter

      assert_equal [10, 20, 30], adapter.find_all(order: :age).map(&:age)
      assert_equal [30, 20, 10], adapter.find_all(order: [:age, :desc]).map(&:age)
    end

    test "find_all applies limit and offset after ordering" do
      [10, 20, 30, 40].each { |age| DynamoidAdapterPlain.create!(name: "n#{age}", age: age) }
      adapter = DynamoidAdapterPlain.to_adapter

      assert_equal [20, 30], adapter.find_all(order: :age, offset: 1, limit: 2).map(&:age)
      assert_equal [10], adapter.find_all(order: :age, limit: 1).map(&:age)
      assert_equal [30, 40], adapter.find_all(order: :age, offset: 2).map(&:age)
    end

    test "create! persists a record" do
      record = User.to_adapter.create!(valid_attributes(email: "adapter-create@example.com"))

      assert record.persisted?
      assert_equal "adapter-create@example.com", User.find(record.id).email
    end

    test "destroy removes the record" do
      user = create_user

      User.to_adapter.destroy(user)

      assert_nil User.to_adapter.get(user.id)
    end

    test "destroy returns nil for an object of another class and leaves it alone" do
      admin = create_admin

      assert_nil User.to_adapter.destroy(admin)
      assert_equal admin.id, Admin.find(admin.id).id
    end

    # 2. increment_counter

    test "increment_counter is atomic across stale in-memory copies" do
      user = create_user
      first_copy = User.find(user.id)
      second_copy = User.find(user.id)
      assert_equal 0, first_copy.sign_in_count
      assert_equal 0, second_copy.sign_in_count

      first_copy.class.increment_counter(:sign_in_count, first_copy.id)
      second_copy.class.increment_counter(:sign_in_count, second_copy.id)

      assert_equal 2, User.find(user.id).sign_in_count
    end

    test "increment_counter works after reload" do
      user = create_user
      User.increment_counter(:sign_in_count, user.id)
      user.reload
      assert_equal 1, user.sign_in_count

      User.increment_counter(:sign_in_count, user.id)
      user.reload

      assert_equal 2, user.sign_in_count
    end

    # 3. Dirty tracking primitives

    test "devise_will_save_change_to_email? and devise_email_in_database reflect a pending change" do
      user = create_user(email: "before@example.com")

      user.email = "after@example.com"

      assert user.devise_will_save_change_to_email?
      assert_equal "before@example.com", user.devise_email_in_database
    end

    test "devise_saved_change_to_email? and devise_email_before_last_save reflect the last save" do
      user = create_user(email: "old@example.com")
      user.email = "new@example.com"

      user.save!

      assert user.devise_saved_change_to_email?
      assert_equal "old@example.com", user.devise_email_before_last_save
    end

    test "a save without an email change clears devise_saved_change_to_email?" do
      user = create_user(email: "steady@example.com")
      user.email = "changed@example.com"
      user.save!
      assert user.devise_saved_change_to_email?

      user.save!

      refute user.devise_saved_change_to_email?
    end

    test "dirty values are correct inside after_update" do
      record = DynamoidAdapterCallback.create!(email: "cb-old@example.com")
      record.email = "cb-new@example.com"

      record.save!

      assert_equal [true, "cb-old@example.com"], record.captured
    end

    test "devise_saved_change_to_encrypted_password? is true after a password change" do
      user = create_user
      user.password = "a-new-password"
      user.password_confirmation = "a-new-password"
      user.save!

      assert user.devise_saved_change_to_encrypted_password?

      user.save!

      refute user.devise_saved_change_to_encrypted_password?
    end

    test "devise_unconfirmed_email_will_change! forces the next save to write an unchanged value" do
      admin = create_admin
      admin.unconfirmed_email = "model@example.com"
      admin.save!
      # Change the stored value behind the model's back.
      Admin.update_fields(admin.id, unconfirmed_email: "db@example.com")
      assert_equal "model@example.com", admin.unconfirmed_email

      admin.devise_unconfirmed_email_will_change!
      admin.save!
      admin.reload

      assert_equal "model@example.com", admin.unconfirmed_email
      assert_equal "model@example.com", Admin.find(admin.id).unconfirmed_email
    end

    test "devise_respond_to_and_will_save_change_to_attribute? answers for a Symbol" do
      user = create_user(email: "respond@example.com")
      refute user.devise_respond_to_and_will_save_change_to_attribute?(:email)

      user.email = "respond-changed@example.com"

      assert user.devise_respond_to_and_will_save_change_to_attribute?(:email)
    end

    test "devise_respond_to_and_will_save_change_to_attribute? is false for an unknown attribute" do
      user = create_user

      assert_equal false, user.devise_respond_to_and_will_save_change_to_attribute?(:no_such_attribute)
    end

    test "devise_respond_to_and_will_save_change_to_attribute? is false for an Array without raising" do
      user = create_user

      assert_equal false, user.devise_respond_to_and_will_save_change_to_attribute?([:email, true])
    end

    # 4. Uniqueness validator

    test "duplicate email on User is rejected with the taken message" do
      create_user(email: "taken@example.com")
      other = new_user(email: "taken@example.com")

      refute other.valid?
      assert_includes other.errors[:email], "has already been taken"
    end

    test "re-saving the same User is valid" do
      user = create_user(email: "resave@example.com")

      assert user.valid?
    end

    test "blank values are allowed by the uniqueness validator" do
      DynamoidAdapterCaseSensitive.create!(email: nil)
      blank = DynamoidAdapterCaseSensitive.new(email: nil)

      assert blank.valid?
    end

    test "case_sensitive true allows values differing only by case" do
      DynamoidAdapterCaseSensitive.create!(email: "A@x.com")

      assert DynamoidAdapterCaseSensitive.new(email: "a@x.com").valid?
      refute DynamoidAdapterCaseSensitive.new(email: "A@x.com").valid?
    end

    test "case_sensitive false rejects values differing only by case" do
      DynamoidAdapterCaseInsensitive.create!(email: "Mixed@x.com")

      record = DynamoidAdapterCaseInsensitive.new(email: "mixed@x.com")

      refute record.valid?
      assert_includes record.errors[:email], "has already been taken"
    end

    test "scope allows duplicates across different scope values" do
      DynamoidAdapterScoped.create!(email: "scoped@x.com", account_id: "1")

      assert DynamoidAdapterScoped.new(email: "scoped@x.com", account_id: "2").valid?
      refute DynamoidAdapterScoped.new(email: "scoped@x.com", account_id: "1").valid?
    end

    test "uniqueness works on a model without a GSI" do
      DynamoidAdapterUnindexed.create!(email: "no-gsi@x.com")

      record = DynamoidAdapterUnindexed.new(email: "no-gsi@x.com")

      refute record.valid?
      assert_includes record.errors[:email], "has already been taken"
    end

    # 5. Devise::Orm detection

    test "Devise::Orm.dynamodb? is true for a Dynamoid model" do
      assert Devise::Orm.dynamodb?(User)
    end

    test "Devise::Orm.dynamodb? is false for a plain Class" do
      refute Devise::Orm.dynamodb?(Class.new)
    end

    test "Dynamoid models include DirtyTrackingDynamodbMethods" do
      assert User.include?(Devise::Orm::DirtyTrackingDynamodbMethods)
      assert Admin.include?(Devise::Orm::DirtyTrackingDynamodbMethods)
    end

    # 6. Dispatcher

    test "library_path maps :dynamoid to the dynamoid adapter" do
      assert_equal "devise/orm/dynamoid", Devise::Orm::Dynamodb.library_path(:dynamoid)
    end

    test "library_path maps :aws_record and 'aws-record' to the aws_record adapter" do
      assert_equal "devise/orm/aws_record", Devise::Orm::Dynamodb.library_path(:aws_record)
      assert_equal "devise/orm/aws_record", Devise::Orm::Dynamodb.library_path("aws-record")
    end

    test "library_path raises ArgumentError for an unknown library" do
      assert_raises(ArgumentError) { Devise::Orm::Dynamodb.library_path(:bogus) }
    end

    test "Devise.dynamodb_library defaults to :dynamoid" do
      assert_equal :dynamoid, Devise.dynamodb_library
    end

    # 7. update, serialization, nested save

    test "update returns false and does not persist when invalid" do
      user = create_user(email: "keep@example.com")

      refute user.update(email: "")

      assert_equal "keep@example.com", User.find(user.id).email
    end

    test "update! raises DocumentNotValid when invalid" do
      user = create_user

      assert_raises(Dynamoid::Errors::DocumentNotValid) do
        user.update!(email: "")
      end
    end

    test "a nested save in after_create does not raise" do
      record = nil

      assert_nothing_raised do
        record = DynamoidAdapterNestedSave.create!(email: "nested@example.com")
      end

      assert_equal "nested@example.com", DynamoidAdapterNestedSave.find(record.id).email
    end

    test "serializable_hash includes nil fields and excludes Devise unsafe attributes" do
      user = create_user(email: "serial@example.com")

      hash = user.serializable_hash

      assert hash.key?("facebook_token")
      assert_nil hash["facebook_token"]
      assert_equal "serial@example.com", hash["email"]
      Devise::Models::Authenticatable::UNSAFE_ATTRIBUTES_FOR_SERIALIZATION.each do |attribute|
        refute hash.key?(attribute.to_s), "expected #{attribute} to be excluded"
      end
    end
  end
end
