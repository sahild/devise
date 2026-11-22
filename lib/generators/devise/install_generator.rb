# frozen_string_literal: true

require 'rails/generators/base'
require 'securerandom'

module Devise
  module Generators
    MissingORMError = Class.new(Thor::Error)

    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Creates a Devise initializer and copy locale files to your application."
      class_option :orm, required: true
      class_option :dynamodb_library, type: :string, default: "dynamoid",
        desc: "Library used with --orm=dynamodb: dynamoid or aws_record"

      DYNAMODB_ORMS = %w(dynamodb dynamoid aws_record).freeze
      DYNAMODB_LIBRARIES = %w(dynamoid aws_record).freeze

      def copy_initializer
        unless options[:orm]
          raise MissingORMError, <<-ERROR.strip_heredoc
          An ORM must be set to install Devise in your application.

          Be sure to have an ORM like Active Record or Mongoid loaded in your
          app or configure your own at `config/application.rb`.

            config.generators do |g|
              g.orm :your_orm_gem
            end
          ERROR
        end

        if dynamodb? && !DYNAMODB_LIBRARIES.include?(dynamodb_library.to_s)
          raise Thor::Error, "Unknown DynamoDB library #{dynamodb_library.to_s.inspect}. " \
            "Use one of: #{DYNAMODB_LIBRARIES.join(', ')}."
        end

        template "devise.rb", "config/initializers/devise.rb"
      end

      no_tasks do
        # --orm=dynamodb, or the name of a DynamoDB library (--orm=dynamoid /
        # --orm=aws_record, e.g. from `config.generators.orm`).
        def dynamodb?
          DYNAMODB_ORMS.include?(options[:orm].to_s)
        end

        def dynamodb_library
          orm = options[:orm].to_s
          DYNAMODB_LIBRARIES.include?(orm) ? orm.to_sym : options[:dynamodb_library].to_sym
        end

        def orm_file
          dynamodb? ? "dynamodb" : options[:orm]
        end
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
