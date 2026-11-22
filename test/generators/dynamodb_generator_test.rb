# frozen_string_literal: true

require "test_helper"
require "generators/dynamodb/devise_generator"

class DynamodbGeneratorTest < Rails::Generators::TestCase
  tests Dynamodb::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "creates a Dynamoid model by default" do
    run_generator %w(monster --library=dynamoid)
    assert_file "app/models/monster.rb" do |content|
      assert_match(/class Monster\n  include Dynamoid::Document\n/, content)
      assert_match(/devise :database_authenticatable, :registerable/, content)
      assert_match(/field :email,\s+:string, default: ""/, content)
      assert_match(/field :encrypted_password, :string, default: ""/, content)
      assert_match(/# field :confirmation_token,\s+:string/, content)
      assert_match(/global_secondary_index hash_key: :email, projected_attributes: :keys_only/, content)
    end
    assert_no_directory "db/migrate"
  end

  test "creates an aws-record model" do
    run_generator %w(monster --library=aws_record)
    assert_file "app/models/monster.rb" do |content|
      assert_match(/class Monster\n  include Aws::Record\n/, content)
      assert_match(/string_attr :id, hash_key: true/, content)
      assert_match(/string_attr :email$/, content)
      assert_match(/time_attr\s+:reset_password_sent_at, formatter: Devise::Orm::Dynamodb::TimeFormatter/, content)
      assert_match(/global_secondary_index :email_index, hash_key: :email/, content)
      assert_match(/devise :database_authenticatable/, content)
    end
  end

  test "defaults to Devise.dynamodb_library" do
    swap Devise, dynamodb_library: :aws_record do
      run_generator %w(monster)
      assert_file "app/models/monster.rb", /include Aws::Record/
    end
  end

  test "generated models are valid Ruby" do
    %w(dynamoid aws_record).each do |library|
      prepare_destination
      run_generator ["monster", "--library=#{library}"]
      assert_file "app/models/monster.rb" do |content|
        assert RubyVM::InstructionSequence.compile(content), "#{library} model should compile"
      end
    end
  end

  test "namespaced models" do
    run_generator %w(admin/monster --library=dynamoid)
    assert_file "app/models/admin/monster.rb" do |content|
      assert_match(/module Admin\n  class Monster\n    include Dynamoid::Document\n/, content)
      assert_match(/^    devise :database_authenticatable/, content)
      assert_match(/^    field :email/, content)
      assert RubyVM::InstructionSequence.compile(content)
    end
  end

  test "adds Devise to an existing model" do
    FileUtils.mkdir_p(File.join(destination_root, "app/models"))
    File.write(File.join(destination_root, "app/models/monster.rb"), <<~RUBY)
      class Monster
        include Dynamoid::Document

        field :name, :string
      end
    RUBY

    run_generator %w(monster --library=dynamoid)
    assert_file "app/models/monster.rb" do |content|
      assert_match(/field :name, :string/, content)
      assert_match(/devise :database_authenticatable/, content)
      assert_match(/field :email/, content)
    end
  end

  test "rejects unknown libraries" do
    content = capture(:stderr) { run_generator %w(monster --library=mongo) }
    assert_match(/Unknown DynamoDB library "mongo"/, content)
    assert_no_file "app/models/monster.rb"
  end

  test "all files are properly deleted" do
    run_generator %w(monster --library=dynamoid)
    run_generator %w(monster --library=dynamoid), behavior: :revoke
    assert_no_file "app/models/monster.rb"
  end
end

require "generators/dynamoid/devise_generator"
require "generators/aws_record/devise_generator"

class DynamoidOrmGeneratorTest < Rails::Generators::TestCase
  tests Dynamoid::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "is used for the :dynamoid generator ORM" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb", /include Dynamoid::Document/
  end
end

class AwsRecordOrmGeneratorTest < Rails::Generators::TestCase
  tests AwsRecord::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "is used for the :aws_record generator ORM" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb", /include Aws::Record/
  end
end
