# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  # Models sharing one table, told apart by a `type` attribute (Active Record
  # style single table inheritance), with a keys-only email index.
  class DynamodbInheritanceTest < ActiveSupport::TestCase
    Member = if DEVISE_ORM == :dynamoid
      Class.new do
        include Dynamoid::Document
        def self.name; "StiMember"; end
        table name: :sti_members, capacity_mode: :on_demand
        field :type, :string
        field :email, :string, default: ""
        field :encrypted_password, :string, default: ""
        global_secondary_index hash_key: :email, projected_attributes: :keys_only
        devise :database_authenticatable, :validatable
      end
    else
      Class.new do
        include Aws::Record
        def self.name; "StiMember"; end
        set_table_name "#{Shim.table_prefix}sti_members"
        string_attr :id, hash_key: true
        string_attr :type
        string_attr :email
        string_attr :encrypted_password
        global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "KEYS_ONLY" }
        devise :database_authenticatable, :validatable
      end
    end
    Object.const_set(:StiMember, Member) unless defined?(::StiMember)

    Boss = Class.new(::StiMember) { def self.name; "StiBoss"; end }
    Object.const_set(:StiBoss, Boss) unless defined?(::StiBoss)

    Devise::Orm::Dynamodb::Tables.create([::StiMember])
    Minitest.after_run do
      Devise::Orm::Dynamodb::Tables.drop([::StiMember])
      Devise::Orm::Dynamodb.unregister(::StiMember)
      Devise::Orm::Dynamodb.unregister(::StiBoss)
    end

    setup { Devise::Orm::Dynamodb::Tables.truncate([::StiMember]) }

    def create(klass, email)
      klass.create!(email: email, password: "12345678", password_confirmation: "12345678")
    end

    test "records the class name in the type attribute" do
      assert_equal "StiBoss", create(::StiBoss, "boss@example.com").type
      assert_equal "StiMember", create(::StiMember, "member@example.com").type
    end

    test "a subclass cannot find or authenticate parent class records" do
      member = create(::StiMember, "member@example.com")

      assert_nil ::StiBoss.find_for_authentication(email: "member@example.com")
      assert_nil ::StiBoss.to_adapter.get(member.id)
      assert_nil ::StiBoss.serialize_from_session([member.id], member.authenticatable_salt)
    end

    test "the parent class finds subclass records, as with Active Record" do
      boss = create(::StiBoss, "boss@example.com")
      found = ::StiMember.find_for_authentication(email: "boss@example.com")
      assert_equal boss.id, found.id
      assert_equal boss.id, ::StiMember.to_adapter.get(boss.id).id
    end

    test "indexed lookups work with a type field and a keys-only index" do
      boss = create(::StiBoss, "boss@example.com")
      assert_equal boss.id, ::StiBoss.find_for_authentication(email: "boss@example.com").id
    end

    test "email uniqueness spans the whole table" do
      create(::StiMember, "taken@example.com")
      duplicate = ::StiBoss.new(email: "taken@example.com", password: "12345678")
      assert duplicate.invalid?
      assert_equal ["has already been taken"], duplicate.errors[:email]
    end
  end
end
