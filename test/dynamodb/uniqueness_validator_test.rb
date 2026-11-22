# frozen_string_literal: true

require "test_helper"

if Devise::Test.dynamodb?
  class DynamodbUniquenessValidatorTest < ActiveSupport::TestCase
    test "validatable rejects a duplicate email like Active Record" do
      user = create_user
      duplicate = new_user(email: user.email)
      assert duplicate.invalid?
      assert_equal ["has already been taken"], duplicate.errors[:email]
    end

    test "an existing record does not conflict with itself" do
      user = create_user
      user.email = user.email
      assert user.valid?

      user.username = "changed"
      assert user.valid?
    end

    test "only runs when the email changes" do
      user = create_user
      other = create_user
      other.update_attribute(:email, user.email)

      user.username = "changed"
      assert user.valid?
    end

    test "is case sensitive, like Devise's validatable on Active Record" do
      user = create_user
      swap Devise, case_insensitive_keys: [] do
        duplicate = User.new(valid_attributes(email: user.email.upcase))
        duplicate.valid?
        assert_empty duplicate.errors[:email]
      end
    end

    test "allows blank emails (presence is validated separately)" do
      validator = Devise::Orm::Dynamodb::UniquenessValidator.new(attributes: [:email], allow_blank: true)
      record = User.new(email: "")
      validator.validate(record)
      assert_empty record.errors[:email]
    end

    test "supports scope" do
      create_user(email: "same@example.com", username: "one")
      klass = Class.new(User) do
        def self.name
          "ScopedUniquenessUser"
        end
        validates_uniqueness_of :email, scope: :username
      end
      other = klass.new(valid_attributes(email: "same@example.com", username: "two"))
      other.valid?
      assert_equal 1, other.errors[:email].size
    end

    test "custom messages" do
      user = create_user
      validator = Devise::Orm::Dynamodb::UniquenessValidator.new(attributes: [:email], message: "is in use")
      record = User.new(email: user.email)
      validator.validate(record)
      assert_equal ["is in use"], record.errors[:email]
    end

    test "rejects case_sensitive: false" do
      assert_raise(ArgumentError) do
        Devise::Orm::Dynamodb::UniquenessValidator.new(attributes: [:email], case_sensitive: false)
      end
    end

    test "can be used through validates :uniqueness" do
      assert_equal Devise::Orm::Dynamodb::UniquenessValidator,
        Devise::Orm::Dynamodb::Validations::UniquenessValidator
    end
  end
end
