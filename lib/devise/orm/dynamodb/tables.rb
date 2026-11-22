# frozen_string_literal: true

module Devise
  module Orm
    module Dynamodb
      # Creates and drops the DynamoDB tables of Devise models. Used by the
      # `devise:dynamodb:*` rake tasks and the test suite.
      module Tables
        module_function

        # Devise DynamoDB models of the application. Loads the application's
        # models and Devise mappings first, so every model calling `devise` is
        # registered.
        def models
          load_models!
          Devise::Orm::Dynamodb.models.reject { |model| model.name.nil? }
        end

        # Only the root model of each table (subclasses share their parent's
        # table, like Active Record single table inheritance).
        def table_models(models = self.models)
          models.uniq { |model| table_name(model) }
        end

        def table_name(model)
          backend(model).table_name(model)
        end

        def exists?(model)
          backend(model).table_exists?(model)
        end

        # Creates the tables that do not exist yet. Returns the models whose
        # table was created.
        def create(models = self.models)
          table_models(models).reject { |model| exists?(model) }.each do |model|
            backend(model).create_table(model)
          end
        end

        # Drops the tables that exist. Returns the models whose table was dropped.
        def drop(models = self.models)
          table_models(models).select { |model| exists?(model) }.each do |model|
            backend(model).drop_table(model)
          end
        end

        # Deletes every item of each table, keeping the tables.
        def truncate(models = self.models)
          table_models(models).each do |model|
            next unless exists?(model)

            client = backend(model).client(model)
            key = backend(model).hash_key_storage_name(model)
            name = table_name(model)

            client.scan(table_name: name, projection_expression: '#k', expression_attribute_names: { '#k' => key }).each_page do |page|
              page.items.each_slice(25) do |items|
                requests = items.map { |item| { delete_request: { key: { key => item[key] } } } }
                batch_write(client, name, requests)
              end
            end
          end
        end

        # One line per table: [model name, table name, exists?, index names]
        def status(models = self.models)
          table_models(models).map do |model|
            [model.name, table_name(model), exists?(model), backend(model).index_names(model)]
          end
        end

        # Writes a batch, retrying the requests DynamoDB reports as
        # unprocessed (e.g. when throttled) with exponential backoff.
        def batch_write(client, table_name, requests, attempts: 8)
          attempts.times do |attempt|
            response = client.batch_write_item(request_items: { table_name => requests })
            requests = (response.unprocessed_items || {})[table_name] || []
            return if requests.empty?

            sleep(0.05 * (2**attempt))
          end

          raise "Could not delete #{requests.size} item(s) from #{table_name}: DynamoDB kept returning them as unprocessed"
        end

        def backend(model)
          Devise::Orm::Dynamodb.backend_for(model)
        end

        def load_models!
          if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
            Rails.application.eager_load!
            Devise.mappings.each_value(&:to)
          end
        end
      end
    end
  end
end
