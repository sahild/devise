# frozen_string_literal: true

require "devise/orm/dynamodb/tasks"

namespace :devise do
  namespace :dynamodb do
    desc "Create DynamoDB tables for Devise models that do not exist yet"
    task create_tables: :environment do
      classes = Devise::Orm::Dynamodb::Tasks.dynamodb_classes(Devise.mappings)
      Devise::Orm::Dynamodb::Tasks.new(classes).create_tables
    end

    desc "Drop DynamoDB tables for Devise models (refuses in production unless FORCE=1)"
    task drop_tables: :environment do
      classes = Devise::Orm::Dynamodb::Tasks.dynamodb_classes(Devise.mappings)
      Devise::Orm::Dynamodb::Tasks.new(classes).drop_tables
    end

    desc "Verify connectivity to DynamoDB"
    task ping: :environment do
      Devise::Orm::Dynamodb::Tasks.new([]).ping
    end
  end
end
