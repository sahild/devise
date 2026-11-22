# frozen_string_literal: true

require 'rails/generators/named_base'
require 'generators/devise/orm_helpers'

module Dynamoid
  module Generators
    class DeviseGenerator < Rails::Generators::NamedBase
      include Devise::Generators::OrmHelpers

      # Dynamoid has no model generator, so the model file is created here when
      # it does not exist yet. The Devise fields and the devise call are then
      # injected in both cases, so they appear exactly once.
      def generate_model
        create_file model_path, model_template unless model_exists? && behavior == :invoke
      end

      def inject_field_types
        inject_into_file model_path, migration_data, after: "include Dynamoid::Document\n" if model_exists?
      end

      def inject_devise_content
        inject_into_file model_path, model_contents, after: "include Dynamoid::Document\n" if model_exists?
      end

      def model_template
<<RUBY
class #{class_name}
  include Dynamoid::Document

  table name: :#{plural_table_name}, key: :id

  # Global secondary index used for lookups by email (Devise's find_for_authentication
  # and the uniqueness validator).
  global_secondary_index hash_key: :email, projected_attributes: :all
  # global_secondary_index hash_key: :confirmation_token, projected_attributes: :all
  # global_secondary_index hash_key: :reset_password_token, projected_attributes: :all
  # global_secondary_index hash_key: :unlock_token, projected_attributes: :all
end
RUBY
      end

      def migration_data
<<RUBY
  ## Database authenticatable
  field :email, :string
  field :encrypted_password, :string, default: ""

  ## Recoverable
  field :reset_password_token, :string
  field :reset_password_sent_at, :datetime

  ## Rememberable
  field :remember_created_at, :datetime

  ## Trackable
  # field :sign_in_count, :integer, default: 0
  # field :current_sign_in_at, :datetime
  # field :last_sign_in_at, :datetime
  # field :current_sign_in_ip, :string
  # field :last_sign_in_ip, :string

  ## Confirmable
  # field :confirmation_token, :string
  # field :confirmed_at, :datetime
  # field :confirmation_sent_at, :datetime
  # field :unconfirmed_email, :string # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, :integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token, :string # Only if unlock strategy is :email or :both
  # field :locked_at, :datetime

RUBY
      end
    end
  end
end
