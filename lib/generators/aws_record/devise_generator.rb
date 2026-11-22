# frozen_string_literal: true

require 'rails/generators/named_base'
require 'generators/devise/orm_helpers'

module AwsRecord
  module Generators
    class DeviseGenerator < Rails::Generators::NamedBase
      include Devise::Generators::OrmHelpers

      # The lines that make a model an aws-record Devise model. Kept in one place
      # so they can be adjusted when the Devise::Orm::AwsRecordSupport API changes.
      SUPPORT_INCLUDE = "include Devise::Orm::AwsRecordSupport"
      MODEL_BASE_LINES = [
        "include Aws::Record",
        SUPPORT_INCLUDE
      ].freeze

      # aws-record has no model generator, so the model file is created here when
      # it does not exist yet. The Devise fields and the devise call are then
      # injected in both cases, so they appear exactly once.
      def generate_model
        create_file model_path, model_template unless model_exists? && behavior == :invoke
      end

      # `devise` is only defined once Devise::Orm::AwsRecordSupport is included,
      # so make sure an existing model includes it and inject after that line.
      def inject_support_include
        return unless model_exists?
        return if File.read(File.join(destination_root, model_path)).include?(SUPPORT_INCLUDE)

        inject_into_file model_path, "  #{SUPPORT_INCLUDE}\n", after: "include Aws::Record\n"
      end

      def inject_field_types
        inject_into_file model_path, migration_data, after: "#{SUPPORT_INCLUDE}\n" if model_exists?
      end

      def inject_devise_content
        inject_into_file model_path, model_contents, after: "#{SUPPORT_INCLUDE}\n" if model_exists?
      end

      def model_template
<<RUBY
class #{class_name}
#{MODEL_BASE_LINES.map { |line| "  #{line}" }.join("\n")}

  set_table_name "#{plural_table_name}"

  # The `id` hash key (string, UUID assigned on create) is declared by
  # Devise::Orm::AwsRecordSupport.

  # Global secondary index used for lookups by email (Devise's find_for_authentication
  # and the uniqueness validator).
  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "ALL" }
  # global_secondary_index :confirmation_token_index, hash_key: :confirmation_token, projection: { projection_type: "ALL" }
  # global_secondary_index :reset_password_token_index, hash_key: :reset_password_token, projection: { projection_type: "ALL" }
  # global_secondary_index :unlock_token_index, hash_key: :unlock_token, projection: { projection_type: "ALL" }
end
RUBY
      end

      def migration_data
<<RUBY
  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  datetime_attr :reset_password_sent_at

  ## Rememberable
  datetime_attr :remember_created_at

  ## Trackable
  # integer_attr :sign_in_count, default_value: 0
  # datetime_attr :current_sign_in_at
  # datetime_attr :last_sign_in_at
  # string_attr :current_sign_in_ip
  # string_attr :last_sign_in_ip

  ## Confirmable
  # string_attr :confirmation_token
  # datetime_attr :confirmed_at
  # datetime_attr :confirmation_sent_at
  # string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  # integer_attr :failed_attempts, default_value: 0 # Only if lock strategy is :failed_attempts
  # string_attr :unlock_token # Only if unlock strategy is :email or :both
  # datetime_attr :locked_at

RUBY
      end
    end
  end
end
