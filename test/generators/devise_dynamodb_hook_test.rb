# frozen_string_literal: true

require "test_helper"
require "generators/devise/devise_generator"

class DeviseDynamodbHookTest < Rails::Generators::TestCase
  tests Devise::Generators::DeviseGenerator
  destination File.expand_path("../../tmp", __FILE__)

  setup do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    FileUtils.cp File.expand_path("../../rails_app/config/routes.rb", __FILE__), File.join(destination_root, "config")
  end

  { "dynamodb" => /include Dynamoid::Document/,
    "dynamoid" => /include Dynamoid::Document/,
    "aws_record" => /include Aws::Record/ }.each do |orm, model_content|
    test "rails g devise uses the DynamoDB model generator for --orm=#{orm}" do
      # --orm=dynamodb follows Devise.dynamodb_library (default :dynamoid).
      swap(Devise, dynamodb_library: :dynamoid) { run_generator ["monster", "--orm=#{orm}"] }
      assert_file "app/models/monster.rb", model_content
      assert_file "app/models/monster.rb", /devise :database_authenticatable/
      assert_file "config/routes.rb", /devise_for :monsters/
      assert_no_directory "db/migrate"
    end
  end
end
