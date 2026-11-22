# frozen_string_literal: true

# User stored in Amazon DynamoDB through Dynamoid, Devise's default DynamoDB
# library. When the app runs with DYNAMODB_LIBRARY=aws_record this file is
# replaced by app/models_aws_record/user.rb (see config/application.rb).
class User
  include Dynamoid::Document

  # Devise models need a table with a partition key only (no sort key).
  table capacity_mode: :on_demand

  ## Database authenticatable
  field :email,              :string, default: ""
  field :encrypted_password, :string, default: ""

  ## Recoverable
  field :reset_password_token,   :string
  field :reset_password_sent_at, :datetime

  ## Rememberable
  field :remember_created_at, :datetime

  ## Trackable
  field :sign_in_count,      :integer, default: 0
  field :current_sign_in_at, :datetime
  field :last_sign_in_at,    :datetime
  field :current_sign_in_ip, :string
  field :last_sign_in_ip,    :string

  ## Confirmable
  field :confirmation_token,   :string
  field :confirmed_at,         :datetime
  field :confirmation_sent_at, :datetime
  field :unconfirmed_email,    :string # Only if using reconfirmable

  ## Lockable
  field :failed_attempts, :integer, default: 0 # Only if lock strategy is :failed_attempts
  field :unlock_token,    :string # Only if unlock strategy is :email or :both
  field :locked_at,       :datetime

  # Devise looks users up by email (sign in, password reset, uniqueness
  # validation). This index lets those lookups Query instead of Scan.
  global_secondary_index hash_key: :email, projected_attributes: :keys_only

  # The seven Devise modules supported on DynamoDB, plus :registerable for sign up.
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :confirmable, :trackable, :lockable
end
