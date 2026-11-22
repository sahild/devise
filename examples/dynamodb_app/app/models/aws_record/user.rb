class User
  include Aws::Record
  include Devise::Orm::AwsRecordSupport
  # All seven modules supported by the DynamoDB adapter are enabled.
  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :trackable, :lockable

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  datetime_attr :reset_password_sent_at

  ## Rememberable
  datetime_attr :remember_created_at

  ## Trackable
  integer_attr :sign_in_count, default_value: 0
  datetime_attr :current_sign_in_at
  datetime_attr :last_sign_in_at
  string_attr :current_sign_in_ip
  string_attr :last_sign_in_ip

  ## Confirmable
  string_attr :confirmation_token
  datetime_attr :confirmed_at
  datetime_attr :confirmation_sent_at
  string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  integer_attr :failed_attempts, default_value: 0 # Only if lock strategy is :failed_attempts
  string_attr :unlock_token # Only if unlock strategy is :email or :both
  datetime_attr :locked_at


  # Dynamoid and aws-record store datetimes differently, so each variant of
  # this sample app uses its own table.
  set_table_name "devise_sample_aws_record_#{Rails.env}_users"

  # The `id` hash key (string, UUID assigned on create) is declared by
  # Devise::Orm::AwsRecordSupport.

  # Global secondary index used for lookups by email (Devise's find_for_authentication
  # and the uniqueness validator).
  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "ALL" }
  global_secondary_index :confirmation_token_index, hash_key: :confirmation_token, projection: { projection_type: "ALL" }
  global_secondary_index :reset_password_token_index, hash_key: :reset_password_token, projection: { projection_type: "ALL" }
  global_secondary_index :unlock_token_index, hash_key: :unlock_token, projection: { projection_type: "ALL" }
end
