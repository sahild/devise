# frozen_string_literal: true

# Amazon DynamoDB support for Devise.
#
# Devise talks to DynamoDB through one of two libraries, selected with
# `config.dynamodb_library` in `config/initializers/devise.rb` (it must be set
# before this file is required):
#
#   * :dynamoid   (default) - https://github.com/Dynamoid/dynamoid
#   * :aws_record           - https://github.com/aws/aws-sdk-ruby-record
#
#   Devise.setup do |config|
#     config.dynamodb_library = :dynamoid
#     require 'devise/orm/dynamodb'
#   end
#
# See "DynamoDB" in the README for model setup, table creation and the list of
# behaviours that differ from Active Record.

require 'devise'
require 'active_model'
require 'devise/orm/dynamodb/backends'
require 'devise/orm/dynamodb/uniqueness_validator'
require 'devise/orm/dynamodb/adapter'
require 'devise/orm/dynamodb/tables'

module Devise
  module Orm
    module Dynamodb
      LIBRARIES = {
        dynamoid:   'dynamoid',
        aws_record: 'aws-record'
      }.freeze

      @models = []
      @scan_warnings = {}
      @scan_warnings_mutex = Mutex.new

      class << self
        # Logger used for adapter warnings (e.g. lookups that fall back to a
        # table Scan). Defaults to the Rails logger.
        attr_writer :logger

        def logger
          @logger || (defined?(Rails) && Rails.logger) || Logger.new($stderr)
        end

        # The DynamoDB library selected through `Devise.dynamodb_library`.
        def library
          library = Devise.dynamodb_library.to_s.to_sym
          return library if LIBRARIES.key?(library)

          raise ArgumentError, "Unknown Devise.dynamodb_library #{Devise.dynamodb_library.inspect}. " \
            "Supported values are: #{LIBRARIES.keys.map(&:inspect).join(', ')}."
        end

        # Devise models backed by DynamoDB, in the order they called `devise`.
        def models
          @models.dup
        end

        # Anonymous classes are ignored. A class redefined under the same name
        # (e.g. on code reload in development) replaces the previous one.
        def register(model) #:nodoc:
          return if model.name.nil?

          @models.reject! { |registered| registered.name == model.name }
          @models << model
        end

        def unregister(model) #:nodoc:
          @models.delete(model)
        end

        def backend_for(model) #:nodoc:
          if Devise::Orm.dynamoid?(model)
            Backends::Dynamoid
          elsif Devise::Orm.aws_record?(model)
            Backends::AwsRecord
          else
            raise ArgumentError, "#{model} is not a Dynamoid or aws-record model"
          end
        end

        def compat_module_for(model) #:nodoc:
          backend_for(model)::ModelCompat
        end

        # Logs a warning the first time a model is queried with a given set of
        # keys that cannot be served by its primary key or a global secondary
        # index, so the query falls back to a full table Scan.
        def warn_scan(model, keys) #:nodoc:
          signature = [model.name, keys.map(&:to_s).sort]

          first_time = @scan_warnings_mutex.synchronize do
            next false if @scan_warnings.key?(signature)
            @scan_warnings[signature] = true
          end
          return unless first_time

          logger.warn "[Devise] #{model.name}: looking up records by #{signature.last.join(', ')} " \
            "requires a full table Scan. Add a global secondary index (projecting all attributes) " \
            "on one of these attributes to make this lookup efficient."
        end

        def load_library! #:nodoc:
          gem_name = LIBRARIES.fetch(library)

          begin
            require gem_name
          rescue LoadError => e
            raise LoadError, "Devise is configured to use DynamoDB through the #{gem_name} gem " \
              "(Devise.dynamodb_library = #{library.inspect}) but it could not be loaded. " \
              "Add `gem \"#{gem_name}\"` to your Gemfile. (#{e.message})"
          end

          case library
          when :dynamoid
            install_dynamoid_hooks!
          when :aws_record
            install_aws_record_hooks!
          end
        end

        private

        def install_dynamoid_hooks!
          ActiveSupport.on_load(:dynamoid) do
            ::Dynamoid::Document::ClassMethods.send :include, Devise::Models
            ::Dynamoid::Document::ClassMethods.send :include, Devise::Orm::Dynamodb::ToAdapter
          end
        end

        def install_aws_record_hooks!
          ::Aws::Record::RecordClassMethods.send :include, Devise::Models
          ::Aws::Record::RecordClassMethods.send :include, Devise::Orm::Dynamodb::ToAdapter
        end
      end

      # Gives DynamoDB models the `to_adapter` method Devise uses for lookups,
      # mirroring what the orm_adapter gem does for Active Record and Mongoid.
      module ToAdapter
        def to_adapter
          @_to_adapter ||= Devise::Orm::Dynamodb::Adapter.new(self)
        end
      end
    end
  end
end

# `errors.messages.taken` is defined by Active Record and Mongoid but not by
# Active Model, so DynamoDB-only applications need it for the uniqueness
# validation. It is prepended so that application translations still win.
I18n.load_path.unshift File.expand_path('dynamodb/locale/en.yml', __dir__)

Devise::Orm::Dynamodb.load_library!
