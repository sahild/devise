# frozen_string_literal: true

require 'rails/generators/named_base'
require 'generators/devise/orm_helpers'

module Dynamodb
  module Generators
    # Generates (or updates) a Devise model stored in Amazon DynamoDB, using
    # Dynamoid (default) or aws-record:
    #
    #   rails generate devise User                       # with config.generators.orm :dynamodb
    #   rails generate dynamodb:devise User --library=aws_record
    #
    # DynamoDB has no migrations: fields are declared in the model and tables
    # are created with `rails devise:dynamodb:create`.
    class DeviseGenerator < Rails::Generators::NamedBase
      include Devise::Generators::OrmHelpers

      LIBRARIES = %w(dynamoid aws_record).freeze

      class_option :library, type: :string, default: nil,
        desc: "DynamoDB library: dynamoid or aws_record (defaults to Devise.dynamodb_library)"

      def check_library
        return if LIBRARIES.include?(library)

        raise Thor::Error, "Unknown DynamoDB library #{library.inspect}. Use one of: #{LIBRARIES.join(', ')}."
      end

      def generate_model
        return if model_exists? && behavior == :invoke

        lines = ["# frozen_string_literal: true", ""]
        class_path_names.each_with_index { |name, i| lines << "#{'  ' * i}module #{name}" }
        lines << "#{indent}class #{class_name.demodulize}"
        lines << "#{indent}  #{library_include}"
        lines << "#{indent}end"
        class_path_names.each_index.to_a.reverse_each { |i| lines << "#{'  ' * i}end" }

        create_file model_path, lines.join("\n") << "\n"
      end

      # Fields first, then the `devise` call, so the generated model reads
      # top to bottom like an Active Record model with its schema.
      def inject_devise_content
        return unless model_exists?

        content = "\n" + field_definitions + model_contents.chomp
        inject_into_file model_path, indent_lines(content), after: "#{library_include}\n"
      end

      def show_next_steps
        return unless behavior == :invoke

        say <<~MSG

          #{class_name} is set up to store users in DynamoDB through #{library}.
          Uncomment the fields of any extra modules you enable, then create the table with:

            bin/rails devise:dynamodb:create
        MSG
      end

      no_tasks do
        def library
          (options[:library] || default_library).to_s
        end

        def field_definitions
          library == "aws_record" ? aws_record_fields : dynamoid_fields
        end
      end

      private

      def default_library
        defined?(Devise) && Devise.respond_to?(:dynamodb_library) ? Devise.dynamodb_library : :dynamoid
      end

      def library_include
        library == "aws_record" ? "include Aws::Record" : "include Dynamoid::Document"
      end

      def class_path_names
        class_name.to_s.split("::")[0...-1]
      end

      def indent
        "  " * class_path_names.size
      end

      def indent_lines(content)
        return content if indent.empty?

        content.lines.map { |line| line.strip.empty? ? line : "#{indent}#{line}" }.join
      end

      def dynamoid_fields
        <<RUBY
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
  # field :sign_in_count,      :integer, default: 0
  # field :current_sign_in_at, :datetime
  # field :last_sign_in_at,    :datetime
  # field :current_sign_in_ip, :string
  # field :last_sign_in_ip,    :string

  ## Confirmable
  # field :confirmation_token,   :string
  # field :confirmed_at,         :datetime
  # field :confirmation_sent_at, :datetime
  # field :unconfirmed_email,    :string # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, :integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    :string # Only if unlock strategy is :email or :both
  # field :locked_at,       :datetime

  # Devise looks users up by email (sign in, password reset, uniqueness
  # validation). This index lets those lookups Query instead of Scan.
  # Add similar indexes for other authentication keys you configure.
  global_secondary_index hash_key: :email, projected_attributes: :keys_only

RUBY
      end

      def aws_record_fields
        time = "formatter: Devise::Orm::Dynamodb::TimeFormatter"

        <<RUBY
  # Devise models need a table with a partition key only (no sort key).
  string_attr :id, hash_key: true

  ## Database authenticatable
  string_attr :email
  string_attr :encrypted_password

  ## Recoverable
  string_attr :reset_password_token
  time_attr   :reset_password_sent_at, #{time}

  ## Rememberable
  time_attr :remember_created_at, #{time}

  ## Trackable
  # integer_attr :sign_in_count, default_value: 0
  # time_attr    :current_sign_in_at, #{time}
  # time_attr    :last_sign_in_at, #{time}
  # string_attr  :current_sign_in_ip
  # string_attr  :last_sign_in_ip

  ## Confirmable
  # string_attr :confirmation_token
  # time_attr   :confirmed_at, #{time}
  # time_attr   :confirmation_sent_at, #{time}
  # string_attr :unconfirmed_email # Only if using reconfirmable

  ## Lockable
  # integer_attr :failed_attempts, default_value: 0 # Only if lock strategy is :failed_attempts
  # string_attr  :unlock_token # Only if unlock strategy is :email or :both
  # time_attr    :locked_at, #{time}

  time_attr :created_at, #{time}
  time_attr :updated_at, #{time}

  # Devise looks users up by email (sign in, password reset, uniqueness
  # validation). This index lets those lookups Query instead of Scan.
  # Add similar indexes for other authentication keys you configure.
  global_secondary_index :email_index, hash_key: :email,
    projection: { projection_type: "KEYS_ONLY" }

RUBY
      end
    end
  end
end
