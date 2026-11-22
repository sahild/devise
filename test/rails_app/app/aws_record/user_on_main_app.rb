# frozen_string_literal: true

require 'shared_user_without_omniauth'

class UserOnMainApp
  include Devise::Orm::AwsRecordSupport
  include Shim
  include SharedUserWithoutOmniauth

  set_table_name "devise_aws_record_test_user_on_main_app"

  time_attr :created_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  time_attr :updated_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  string_attr  :username
  string_attr  :facebook_token

  ## Database authenticatable
  string_attr :email

  # Mirrors the ActiveRecord/Mongoid fixtures' `email default: ""`. aws-record's
  # default_value cannot be used: it is re-applied on write and DynamoDB
  # rejects "" as a GSI key (blank GSI keys are dropped on save instead).
  def initialize(attributes = {})
    super
    self.email = "" if email.nil?
  end
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_attr   :reset_password_sent_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Rememberable
  time_attr :remember_created_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Trackable
  integer_attr :sign_in_count, default_value: 0
  time_attr    :current_sign_in_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  time_attr    :last_sign_in_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  string_attr  :current_sign_in_ip
  string_attr  :last_sign_in_ip

  ## Confirmable
  string_attr :confirmation_token
  time_attr   :confirmed_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter
  time_attr   :confirmation_sent_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  ## Lockable
  integer_attr :failed_attempts, default_value: 0
  string_attr  :unlock_token
  time_attr    :locked_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter

  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "ALL" }
end
