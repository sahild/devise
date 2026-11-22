# frozen_string_literal: true

require 'shared_admin'

class Admin
  include Dynamoid::Document
  include Shim
  include SharedAdmin

  ## Database authenticatable
  field :email,              :string

  global_secondary_index hash_key: :email, projected_attributes: :all
  field :encrypted_password, :string

  ## Recoverable
  field :reset_password_token,   :string
  field :reset_password_sent_at, :datetime

  ## Rememberable
  field :remember_created_at, :datetime

  ## Confirmable
  field :confirmation_token,   :string
  field :confirmed_at,         :datetime
  field :confirmation_sent_at, :datetime
  field :unconfirmed_email,    :string # Only if using reconfirmable

  ## Lockable
  field :locked_at, :datetime

  field :active, :boolean, default: false
end
