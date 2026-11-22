# frozen_string_literal: true

require 'shared_admin'

class Admin
  include Aws::Record
  include Shim

  devise_table "admins"

  string_attr :id, hash_key: true

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_field  :reset_password_sent_at

  ## Rememberable
  time_field :remember_created_at

  ## Confirmable
  string_attr :confirmation_token
  time_field  :confirmed_at
  time_field  :confirmation_sent_at
  string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  time_field :locked_at

  boolean_attr :active, default_value: false

  time_field :created_at
  time_field :updated_at

  # Devise lookups by email Query this index instead of Scanning the table.
  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "KEYS_ONLY" }

  include SharedAdmin
end
