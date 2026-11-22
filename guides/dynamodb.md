# Using Devise with Amazon DynamoDB

Devise can store its models in Amazon DynamoDB, using either of two Ruby
modelling libraries:

| Library | `Devise.dynamodb_library` | Notes |
|---|---|---|
| [Dynamoid](https://github.com/Dynamoid/dynamoid) | `:dynamoid` (default) | Full ORM-style API (callbacks, validations, dirty tracking). |
| [aws-record](https://github.com/aws/aws-sdk-ruby-record) | `:aws_record` | AWS's thin data mapper. Devise adds the ActiveModel parts it needs through `Devise::Orm::AwsRecordSupport`. |

## Supported modules

Version 1 supports these modules:

* `database_authenticatable`
* `rememberable`
* `validatable`
* `confirmable` (including `reconfirmable`)
* `trackable`
* `recoverable`
* `lockable`

`registerable` and `timeoutable` do not store anything, so they also work and
are part of the test suite. `omniauthable` is not covered by the DynamoDB
support in v1.

The whole Devise test suite runs against both libraries (`DEVISE_ORM=dynamoid`
and `DEVISE_ORM=aws_record`) on DynamoDB Local.

## Installation

### 1. Add the gems

```ruby
# Gemfile
gem "devise"
gem "dynamoid"      # default library
# or
gem "aws-record"
```

Configure the library itself as usual. For example, for Dynamoid:

```ruby
# config/initializers/dynamoid.rb
Dynamoid.configure do |config|
  config.namespace = "myapp_#{Rails.env}"
  config.region = ENV.fetch("AWS_REGION", "us-east-1")
  config.endpoint = ENV["DYNAMODB_ENDPOINT"] # e.g. http://localhost:8000 for DynamoDB Local
end
```

aws-record uses the standard AWS SDK configuration (`AWS_REGION`, credentials,
and `AWS_ENDPOINT_URL_DYNAMODB` for DynamoDB Local), or `Model.configure_client`.

### 2. Install Devise

```console
# Dynamoid (default library)
rails generate devise:install --orm=dynamodb

# aws-record
rails generate devise:install --orm=dynamodb --dynamodb-library=aws_record
```

This writes the ORM section of `config/initializers/devise.rb`:

```ruby
config.dynamodb_library = :dynamoid # or :aws_record
require 'devise/orm/dynamodb'
```

`config.dynamodb_library` must be set **before** `require 'devise/orm/dynamodb'`.
You can also skip the setting and require a library adapter directly with
`require 'devise/orm/dynamoid'` or `require 'devise/orm/aws_record'`
(that is what `--orm=dynamoid` and `--orm=aws_record` generate).

To make `rails generate devise MODEL` pick the DynamoDB generators, set the
generator ORM in `config/application.rb`:

```ruby
config.generators do |g|
  g.orm :dynamodb # or :dynamoid / :aws_record
end
```

### 3. Generate a model

```console
rails generate devise User                          # uses Devise.dynamodb_library
rails generate dynamodb:devise User --library=aws_record
rails generate dynamoid:devise User
rails generate aws_record:devise User
```

The generator creates `app/models/user.rb` (or injects into an existing one)
with the fields for all seven modules. Fields for `trackable`, `confirmable` and
`lockable` are commented out; uncomment them when you enable those modules.
DynamoDB is schemaless, so there are no migrations.

### 4. Create the tables

```console
bin/rails devise:dynamodb:create_tables  # creates missing tables (with GSIs) for every Devise model
bin/rails devise:dynamodb:ping           # checks the DynamoDB connection
bin/rails devise:dynamodb:drop_tables    # refuses in production unless FORCE=1
```

The tasks work for both libraries and only touch classes mapped with
`devise_for` in your routes. Dynamoid's own `dynamoid:create_tables` task also
still works. For aws-record you can call `User.devise_create_table!` directly.

## Model reference

### Dynamoid

```ruby
class User
  include Dynamoid::Document

  table name: :users, key: :id

  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :trackable, :lockable

  ## Database authenticatable
  field :email,              :string
  field :encrypted_password, :string

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

  # Lookups by email (sign in, uniqueness check) use this index instead of a Scan.
  global_secondary_index hash_key: :email, projected_attributes: :all
  # Optional: avoid Scans for token lookups.
  # global_secondary_index hash_key: :confirmation_token, projected_attributes: :all
  # global_secondary_index hash_key: :reset_password_token, projected_attributes: :all
  # global_secondary_index hash_key: :unlock_token, projected_attributes: :all
end
```

### aws-record

```ruby
class User
  include Aws::Record
  include Devise::Orm::AwsRecordSupport # must come before `devise`

  set_table_name "users"

  devise :database_authenticatable, :registerable, :recoverable, :rememberable,
         :validatable, :confirmable, :trackable, :lockable

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr   :reset_password_token
  datetime_attr :reset_password_sent_at

  ## Rememberable
  datetime_attr :remember_created_at

  ## Trackable
  integer_attr  :sign_in_count, default_value: 0
  datetime_attr :current_sign_in_at
  datetime_attr :last_sign_in_at
  string_attr   :current_sign_in_ip
  string_attr   :last_sign_in_ip

  ## Confirmable
  string_attr   :confirmation_token
  datetime_attr :confirmed_at
  datetime_attr :confirmation_sent_at
  string_attr   :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  integer_attr  :failed_attempts, default_value: 0
  string_attr   :unlock_token
  datetime_attr :locked_at

  global_secondary_index :email_index, hash_key: :email, projection: { projection_type: "ALL" }
end
```

`Devise::Orm::AwsRecordSupport` adds:

* the hash key `string_attr :id` (a UUID is assigned on create), so do not declare `id` yourself,
* ActiveModel validations, validation callbacks and `before/after/around`
  `_save`, `_create`, `_update` and `_destroy` callbacks,
* `save(validate: false)`, `save!`, `create`, `create!`, `update`,
  `update_attribute`, `reload`, `destroy`, `to_key`, `==`, `serializable_hash`,
  attribute predicates (`confirmed_at?`),
* ActiveModel-style dirty tracking (pending and last-saved changes),
* automatic `created_at` / `updated_at` when you declare those attributes,
* `increment_counter`, `devise_create_table!`, an `OrmAdapter`, and
  `validates_uniqueness_of`.

If you need sub-second precision for timestamps (as ActiveRecord has), use
`time_attr :remember_created_at, formatter: Devise::Orm::AwsRecordSupport::MicrosecondTimeFormatter`.

## How Devise's database behaviour is mapped

| Devise needs | ActiveRecord / Mongoid | DynamoDB adapter |
|---|---|---|
| `validates_uniqueness_of :email, case_sensitive: true, allow_blank: true` | DB query (+ unique index) | `Devise::Orm::Dynamodb::UniquenessValidator`: same options (`allow_blank`, `allow_nil`, `case_sensitive`, `scope`, `conditions`, `if`/`unless`, `message`) and the same `:taken` error. Queries the email GSI, or Scans when there is none. |
| Case-insensitive / stripped keys (`case_insensitive_keys`, `strip_whitespace_keys`) | — | Unchanged: Devise downcases and strips before saving and before lookups. |
| `find_for_authentication`, token lookups (`to_adapter.find_first`) | SQL `WHERE` | Query on a GSI whose hash key is in the conditions, otherwise Scan with a filter. A `nil` condition matches items without the attribute, as `IS NULL` does. |
| `to_adapter.get(id)` (sessions, remember-me cookies) | primary key | GetItem on the hash key. |
| Lockable `increment_counter(:failed_attempts, id)` | atomic `UPDATE ... + 1` | Atomic DynamoDB `ADD` update. |
| Dirty tracking (`will_save_change_to_email?`, `saved_change_to_encrypted_password?`, ...) | ActiveModel::Dirty | Same semantics, including inside `after_update` callbacks. |
| Reconfirmable race fix (#5783): always write `unconfirmed_email` | `unconfirmed_email_will_change!` | The attribute is forced into the next write even when unchanged. |
| Confirmation / reconfirmation emails | `after_commit` (AR), `after_create`/`after_update` (Mongoid) | `after_create` / `after_update`, as for Mongoid. |

## Behaviour that differs, or is not supported

* **Uniqueness is not atomic.** DynamoDB has no unique secondary indexes, so
  email uniqueness is a read-then-write check, as Rails' validator is when the
  database has no unique index. Two concurrent sign-ups with the same email can
  both succeed. GSI reads are also eventually consistent, so a record written a
  moment earlier may not be seen yet. If you need a hard guarantee, keep a
  separate table keyed by the normalised email and write it with a conditional
  put (`attribute_not_exists`) in a transaction together with the user.
* **No transactions or `after_commit`.** Devise sends confirmation emails from
  `after_create`/`after_update` (as with Mongoid), so an email can go out even
  if a later step in your own code fails.
* **Scans without GSIs.** A lookup on an attribute without a GSI (e.g.
  `confirmation_token`, `reset_password_token`, `unlock_token`, or an extra
  authentication key) is a full table Scan. That is correct but slow and costly
  on large tables. Add the commented GSIs from the generated model to avoid it.
  Dynamoid logs a warning for Scans unless `warn_on_scan` is disabled.
* **`order` in `find_first`/`find_all`** is applied in memory after the
  query/scan. Devise itself never orders.
* **Empty strings.** DynamoDB cannot store `""` as a GSI key, and Dynamoid
  stores `""` as null by default (`store_empty_string_as_nil`). Do not give
  `email` a `""` default. A blank email is stored as an absent attribute, and
  a lookup for `""` or `nil` matches records without one.
* **aws-record `default_value`** is applied whenever the value is `nil`,
  including when you set an attribute to `nil` on purpose. Do not use
  `default_value` on attributes Devise clears (`encrypted_password`, tokens,
  timestamps).
* **Time precision.** Dynamoid stores datetimes as epoch numbers with fractional
  seconds. aws-record's default `datetime_attr`/`time_attr` formatter keeps
  whole seconds only; use `MicrosecondTimeFormatter` for sub-second precision.
* **Switching libraries.** Dynamoid stores datetimes as epoch numbers;
  aws-record stores ISO 8601 strings. A table written by one library cannot be
  read by the other without converting the data.
* **Primary key.** Models use a single string hash key `id` (a UUID). Composite
  (range) keys are not supported for Devise models.
* **i18n.** Both libraries use the `activemodel` i18n scope, so attribute
  translations go under `activemodel.attributes.user.email`, not
  `activerecord.*`.
* **aws-record subclasses** (single-table inheritance) are not supported.
* **Not in v1:** `omniauthable` is not tested with DynamoDB, and there is no
  migration tool for existing data (DynamoDB is schemaless; new attributes
  simply appear).

## Running Devise's test suite against DynamoDB

Start [DynamoDB Local](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html)
on port 8000 (for example `docker run -p 8000:8000 amazon/dynamodb-local`) and run:

```console
DEVISE_ORM=dynamoid bin/test
DEVISE_ORM=aws_record bin/test
```

Set `DYNAMODB_ENDPOINT` to use another endpoint. The adapter's own tests are in
`test/orm_adapters/`.

## Sample application

`examples/dynamodb_app` is a small Rails app that uses Devise with DynamoDB
(Dynamoid by default, aws-record with `DYNAMODB_LIBRARY=aws_record`). See its
README.
