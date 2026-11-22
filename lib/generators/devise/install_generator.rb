# frozen_string_literal: true

require 'rails/generators/base'
require 'securerandom'

module Devise
  module Generators
    MissingORMError = Class.new(Thor::Error)

    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      DYNAMODB_LIBRARIES = %w(dynamoid aws_record).freeze

      desc "Creates a Devise initializer and copy locale files to your application."
      class_option :orm, required: true
      class_option :dynamodb_library, type: :string, default: "dynamoid",
        desc: "DynamoDB modelling library used when --orm=dynamodb (dynamoid or aws_record)"

      def copy_initializer
        unless options[:orm]
          raise MissingORMError, <<-ERROR.strip_heredoc
          An ORM must be set to install Devise in your application.

          Be sure to have an ORM like Active Record, Mongoid or DynamoDB loaded in your
          app or configure your own at `config/application.rb`.

            config.generators do |g|
              g.orm :your_orm_gem
            end
          ERROR
        end

        if options[:orm] == "dynamodb" && !DYNAMODB_LIBRARIES.include?(options[:dynamodb_library])
          raise Thor::Error, "Unsupported --dynamodb-library #{options[:dynamodb_library].inspect}. " \
            "Supported libraries are: #{DYNAMODB_LIBRARIES.join(', ')}."
        end

        template "devise.rb", "config/initializers/devise.rb"
      end

      def copy_locale
        copy_file "../../../config/locales/en.yml", "config/locales/devise.en.yml"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
