# frozen_string_literal: true

namespace :devise do
  namespace :dynamodb do
    task load_tables: :environment do
      unless defined?(Devise::Orm::Dynamodb::Tables)
        abort "Devise is not configured for DynamoDB. Add `require 'devise/orm/dynamodb'` to config/initializers/devise.rb."
      end
    end

    desc "Create the DynamoDB tables of Devise models that do not exist yet"
    task create: :load_tables do
      tables = Devise::Orm::Dynamodb::Tables
      created = tables.create

      if created.empty?
        puts "All Devise DynamoDB tables already exist."
      else
        created.each { |model| puts "Created table #{tables.table_name(model)} (#{model.name})" }
      end
    end

    desc "Drop the DynamoDB tables of Devise models"
    task drop: :load_tables do
      tables = Devise::Orm::Dynamodb::Tables
      if defined?(Rails) && Rails.env.production? && ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] != "1"
        abort "Refusing to drop DynamoDB tables in production. Set DISABLE_DATABASE_ENVIRONMENT_CHECK=1 to override."
      end

      dropped = tables.drop
      if dropped.empty?
        puts "No Devise DynamoDB tables to drop."
      else
        dropped.each { |model| puts "Dropped table #{tables.table_name(model)} (#{model.name})" }
      end
    end

    desc "Show the DynamoDB tables used by Devise models"
    task status: :load_tables do
      rows = Devise::Orm::Dynamodb::Tables.status
      if rows.empty?
        puts "No Devise models use DynamoDB."
      else
        rows.each do |model, table, exists, indexes|
          state = exists ? "exists" : "missing"
          index_list = indexes.empty? ? "none" : indexes.join(", ")
          puts "#{model}: table #{table} (#{state}), global secondary indexes: #{index_list}"
        end
      end
    end
  end
end
