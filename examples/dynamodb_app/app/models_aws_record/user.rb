# frozen_string_literal: true

# User stored in Amazon DynamoDB through aws-record. Used instead of
# app/models/user.rb when the app runs with DYNAMODB_LIBRARY=aws_record.
class User
  include Aws::Record

  set_table_name "devise_example_aws_record_#{Rails.env}_users"

  # Devise models need a table with a partition key only (no sort key).
  string_attr :id, hash_key: true

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_attr   :reset_password_sent_at, formatter: Devise::Orm::Dynamodb::TimeFormatter

  ## Rememberable
  time_attr :remember_created_at, formatter: Devise::Orm::Dynamodb::TimeFormatter

  ## Trackable
  integer_attr :sign_in_count, default_value: 0
  time_attr    :current_sign_in_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
  time_attr    :last_sign_in_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
  string_attr  :current_sign_in_ip
  string_attr  :last_sign_in_ip

  ## Confirmable
  string_attr :confirmation_token
  time_attr   :confirmed_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
  time_attr   :confirmation_sent_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
  string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  integer_attr :failed_attempts, default_value: 0 # Only if lock strategy is :failed_attempts
  string_attr  :unlock_token # Only if unlock strategy is :email or :both
  time_attr    :locked_at, formatter: Devise::Orm::Dynamodb::TimeFormatter

  time_attr :created_at, formatter: Devise::Orm::Dynamodb::TimeFormatter
  time_attr :updated_at, formatter: Devise::Orm::Dynamodb::TimeFormatter

  # Devise looks users up by email (sign in, password reset, uniqueness
  # validation). This index lets those lookups Query instead of Scan.
  global_secondary_index :email_index, hash_key: :email,
    projection: { projection_type: "KEYS_ONLY" }

  # The seven Devise modules supported on DynamoDB, plus :registerable for sign up.
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :confirmable, :trackable, :lockable
end
