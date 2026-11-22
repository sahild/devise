# frozen_string_literal: true

require 'shared_admin'

class Admin
  include Devise::Orm::AwsRecordSupport
  include Shim
  include SharedAdmin

  set_table_name "devise_aws_record_test_admins"

  time_attr :created_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  time_attr :updated_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_attr   :reset_password_sent_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Rememberable
  time_attr :remember_created_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Confirmable
  string_attr :confirmation_token
  time_attr   :confirmed_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  time_attr   :confirmation_sent_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  time_attr :locked_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  boolean_attr :active, default_value: false

  # Mongoid/ActiveRecord define the predicate for boolean fields automatically.
  def active?
    !!active
  end

  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "ALL" }
end
