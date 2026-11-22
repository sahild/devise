# frozen_string_literal: true

require 'shared_user'

class User
  include Aws::Record
  include Shim

  devise_table "users"

  string_attr :id, hash_key: true
  string_attr :username
  string_attr :facebook_token

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_field  :reset_password_sent_at

  ## Rememberable
  time_field :remember_created_at

  ## Trackable
  integer_attr :sign_in_count, default_value: 0
  time_field   :current_sign_in_at
  time_field   :last_sign_in_at
  string_attr  :current_sign_in_ip
  string_attr  :last_sign_in_ip

  ## Confirmable
  string_attr :confirmation_token
  time_field  :confirmed_at
  time_field  :confirmation_sent_at
  # string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  integer_attr :failed_attempts, default_value: 0 # Only if lock strategy is :failed_attempts
  string_attr  :unlock_token # Only if unlock strategy is :email or :both
  time_field   :locked_at

  time_field :created_at
  time_field :updated_at

  # Devise lookups by email Query this index instead of Scanning the table.
  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "KEYS_ONLY" }

  include SharedUser

  cattr_accessor :validations_performed

  after_validation :after_validation_callback

  def after_validation_callback
    # used to check in our test if the validations were called
    @@validations_performed = true
  end
end
