# frozen_string_literal: true

require "test_helper"

require "generators/dynamoid/devise_generator"
require "generators/aws_record/devise_generator"
require "generators/dynamodb/devise_generator"

class DynamoidGeneratorTest < Rails::Generators::TestCase
  tests Dynamoid::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  if DEVISE_ORM == :dynamoid
    test "generated model loads and is a Devise Dynamoid model" do
      run_generator %w(monster)
      load File.join(destination_root, "app/models/monster.rb")
      assert Devise::Orm.dynamodb?(Monster)
      assert_includes Monster.devise_modules, :validatable
    ensure
      Object.send(:remove_const, :Monster) if defined?(Monster)
    end
  end

  test "all files are properly created" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb", /include Dynamoid::Document/
    assert_file "app/models/monster.rb", /table name: :monsters, key: :id/
    assert_file "app/models/monster.rb", /field :encrypted_password, :string, default: ""/
    assert_file "app/models/monster.rb", /global_secondary_index hash_key: :email, projected_attributes: :all/
    assert_file "app/models/monster.rb", /devise :database_authenticatable/
  end

  test "devise fields appear exactly once" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb" do |content|
      assert_equal 1, content.scan("field :encrypted_password").size
      assert_equal 1, content.scan("devise :database_authenticatable").size
    end
  end

  test "devise fields are injected into an existing model" do
    run_generator %w(monster)
    FileUtils.rm File.join(destination_root, "app/models/monster.rb")
    FileUtils.mkdir_p File.join(destination_root, "app/models")
    File.write File.join(destination_root, "app/models/monster.rb"), <<~RUBY
      class Monster
        include Dynamoid::Document

        field :name, :string
      end
    RUBY

    run_generator %w(monster)
    assert_file "app/models/monster.rb", /field :name, :string/
    assert_file "app/models/monster.rb", /field :encrypted_password, :string/
    assert_file "app/models/monster.rb", /devise :database_authenticatable/
  end

  test "all files are properly deleted" do
    run_generator %w(monster)
    run_generator %w(monster), behavior: :revoke
    assert_no_file "app/models/monster.rb"
  end
end

class AwsRecordGeneratorTest < Rails::Generators::TestCase
  tests AwsRecord::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "all files are properly created" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb", /include Aws::Record/
    assert_file "app/models/monster.rb", /include Devise::Orm::AwsRecordSupport/
    assert_file "app/models/monster.rb", /set_table_name "monsters"/
    model_source = File.read(File.join(destination_root, "app/models/monster.rb"))
    assert_no_match(/string_attr :id/, model_source) # declared by AwsRecordSupport
    assert_file "app/models/monster.rb", /string_attr :encrypted_password$/
    assert_file "app/models/monster.rb", /global_secondary_index :email_index, hash_key: :email/
    assert_file "app/models/monster.rb", /devise :database_authenticatable/
  end

  test "devise fields appear exactly once" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb" do |content|
      assert_equal 1, content.scan("string_attr :encrypted_password").size
      assert_equal 1, content.scan("devise :database_authenticatable").size
    end
  end

  test "devise fields are injected into an existing model" do
    FileUtils.mkdir_p File.join(destination_root, "app/models")
    File.write File.join(destination_root, "app/models/monster.rb"), <<~RUBY
      class Monster
        include Aws::Record

        string_attr :name
      end
    RUBY

    run_generator %w(monster)
    assert_file "app/models/monster.rb", /string_attr :name/
    assert_file "app/models/monster.rb", /string_attr :encrypted_password/
    assert_file "app/models/monster.rb", /devise :database_authenticatable/
    assert_file "app/models/monster.rb" do |content|
      assert_equal 1, content.scan("include Devise::Orm::AwsRecordSupport").size
      assert_operator content.index("include Devise::Orm::AwsRecordSupport"), :<, content.index("devise :database_authenticatable")
    end
  end

  if DEVISE_ORM == :aws_record
    test "generated model loads and is a Devise aws-record model" do
      run_generator %w(monster)
      load File.join(destination_root, "app/models/monster.rb")
      assert Devise::Orm.dynamodb?(Monster)
      assert_equal :id, Monster.hash_key
      assert_includes Monster.devise_modules, :validatable
    ensure
      Object.send(:remove_const, :Monster) if defined?(Monster)
    end
  end

  test "devise is called after the support module is included" do
    run_generator %w(monster)
    assert_file "app/models/monster.rb" do |content|
      assert_operator content.index("include Devise::Orm::AwsRecordSupport"), :<, content.index("devise :database_authenticatable")
    end
  end

  test "all files are properly deleted" do
    run_generator %w(monster)
    run_generator %w(monster), behavior: :revoke
    assert_no_file "app/models/monster.rb"
  end
end

class DynamodbGeneratorTest < Rails::Generators::TestCase
  tests Dynamodb::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "defaults to the dynamoid library" do
    Dynamodb::Generators::DeviseGenerator.any_instance.expects(:invoke).with("dynamoid:devise", ["monster"])
    run_generator %w(monster)
  end

  test "delegates to aws_record with --library=aws_record" do
    Dynamodb::Generators::DeviseGenerator.any_instance.expects(:invoke).with("aws_record:devise", ["monster"])
    run_generator %w(monster --library=aws_record)
  end

  test "rejects an unsupported library" do
    stderr = capture(:stderr) do
      run_generator %w(monster --library=foo)
    end

    assert_match %r{Unsupported DynamoDB library "foo"}, stderr
    assert_no_file "app/models/monster.rb"
  end

  test "generates a dynamoid model with --library=dynamoid" do
    run_generator %w(monster --library=dynamoid)
    assert_file "app/models/monster.rb", /include Dynamoid::Document/
  end

  test "generates an aws-record model with --library=aws_record" do
    run_generator %w(monster --library=aws_record)
    assert_file "app/models/monster.rb", /include Aws::Record/
  end
end

class DynamodbInstallGeneratorTest < Rails::Generators::TestCase
  tests Devise::Generators::InstallGenerator
  destination File.expand_path("../../tmp", __FILE__)
  setup :prepare_destination

  test "--orm=dynamoid requires devise/orm/dynamoid" do
    run_generator ["--orm=dynamoid"]
    assert_file "config/initializers/devise.rb", %r{require 'devise/orm/dynamoid'}
    assert_file "config/initializers/devise.rb" do |content|
      assert_no_match(/dynamodb_library/, content)
    end
  end

  test "--orm=aws_record requires devise/orm/aws_record" do
    run_generator ["--orm=aws_record"]
    assert_file "config/initializers/devise.rb", %r{require 'devise/orm/aws_record'}
  end

  test "--orm=dynamodb defaults to the dynamoid library" do
    run_generator ["--orm=dynamodb"]
    assert_file "config/initializers/devise.rb", /config\.dynamodb_library = :dynamoid/
    assert_file "config/initializers/devise.rb", %r{require 'devise/orm/dynamodb'}
  end

  test "--orm=dynamodb --dynamodb-library=aws_record sets the aws_record library" do
    run_generator ["--orm=dynamodb", "--dynamodb-library=aws_record"]
    assert_file "config/initializers/devise.rb", /config\.dynamodb_library = :aws_record/
    assert_file "config/initializers/devise.rb", %r{require 'devise/orm/dynamodb'}
  end

  test "--orm=dynamodb rejects an unsupported library" do
    stderr = capture(:stderr) do
      run_generator ["--orm=dynamodb", "--dynamodb-library=foo"]
    end

    assert_match %r{Unsupported --dynamodb-library}, stderr
    assert_no_file "config/initializers/devise.rb"
  end
end
