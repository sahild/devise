# frozen_string_literal: true

module Devise
  module Orm
    module Dynamodb
      # Plain Ruby implementation of the `devise:dynamodb:*` rake tasks so it can
      # be unit tested without loading rake. The rake file is a thin wrapper.
      #
      # Table handling is delegated to the model classes, so this module does not
      # require dynamoid or aws-record at load time:
      #
      #   * Dynamoid models respond to `create_table(sync: true)` and
      #     `table_name`, and the adapter exposes `Dynamoid.adapter.list_tables`.
      #   * aws-record models (`include Aws::Record`) use
      #     `Aws::Record::TableMigration`, and `table_exists?` for detection.
      class Tasks
        def initialize(classes, output: $stdout, dynamoid_adapter: nil)
          @classes = classes
          @output = output
          @dynamoid_adapter = dynamoid_adapter
        end

        # Classes from Devise.mappings that are DynamoDB models.
        def self.dynamodb_classes(mappings)
          mappings.values.map(&:to).uniq.select { |klass| dynamodb_class?(klass) }
        end

        def self.dynamodb_class?(klass)
          return false unless klass.is_a?(Class)

          (defined?(::Dynamoid::Document) && klass.include?(::Dynamoid::Document)) ||
            (defined?(::Aws::Record) && klass.include?(::Aws::Record))
        end

        # Creates the table of each model when it is missing.
        def create_tables
          @classes.each do |klass|
            if table_exists?(klass)
              @output.puts "#{klass.table_name} already exists"
            else
              create_table(klass)
              @output.puts "#{klass.table_name} created"
            end
          end
        end

        # Deletes the table of each model. Refuses in production unless FORCE=1.
        def drop_tables(env: rails_env, force: ENV["FORCE"] == "1")
          if env == "production" && !force
            raise "Refusing to drop DynamoDB tables in production. Set FORCE=1 to override."
          end

          @classes.each do |klass|
            if table_exists?(klass)
              delete_table(klass)
              @output.puts "#{klass.table_name} dropped"
            else
              @output.puts "#{klass.table_name} does not exist"
            end
          end
        end

        # Verifies connectivity using the first available library.
        def ping
          if @dynamoid_adapter || defined?(::Dynamoid)
            dynamoid_adapter.list_tables
          elsif defined?(::Aws::DynamoDB::Client)
            ::Aws::DynamoDB::Client.new.list_tables(limit: 1)
          else
            raise "Neither Dynamoid nor aws-record is loaded"
          end

          @output.puts "DynamoDB is reachable"
          true
        rescue StandardError => e
          @output.puts "DynamoDB is not reachable: #{e.message}"
          false
        end

        private

        def table_exists?(klass)
          if aws_record?(klass)
            klass.table_exists?
          else
            dynamoid_adapter.list_tables.include?(klass.table_name)
          end
        end

        def dynamoid_adapter
          @dynamoid_adapter || ::Dynamoid.adapter
        end

        def create_table(klass)
          if aws_record?(klass)
            if klass.respond_to?(:devise_create_table!)
              klass.devise_create_table!
            else
              ::Aws::Record::TableMigration.new(klass).create!(billing_mode: "PAY_PER_REQUEST")
            end
          else
            klass.create_table(sync: true)
          end
        end

        def delete_table(klass)
          if aws_record?(klass)
            ::Aws::Record::TableMigration.new(klass).delete!
          else
            klass.delete_table
          end
        end

        def aws_record?(klass)
          defined?(::Aws::Record) && klass.is_a?(Class) && klass.include?(::Aws::Record)
        end

        def rails_env
          defined?(::Rails) ? ::Rails.env.to_s : ENV.fetch("RAILS_ENV", "development")
        end
      end
    end
  end
end
