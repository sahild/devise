# frozen_string_literal: true

require 'rails/generators/named_base'

module Dynamodb
  module Generators
    # Dispatches to the DynamoDB modelling library selected with --library
    # (defaults to Devise.dynamodb_library).
    class DeviseGenerator < Rails::Generators::NamedBase
      LIBRARIES = %w(dynamoid aws_record).freeze

      class_option :library, type: :string, default: Devise.dynamodb_library.to_s,
        desc: "DynamoDB modelling library to use (#{LIBRARIES.join(', ')})"

      def generate_model
        unless LIBRARIES.include?(options[:library])
          raise Thor::Error, "Unsupported DynamoDB library #{options[:library].inspect}. " \
            "Supported libraries are: #{LIBRARIES.join(', ')}."
        end

        invoke "#{options[:library]}:devise", [name]
      end
    end
  end
end
