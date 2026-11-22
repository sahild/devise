# frozen_string_literal: true

require 'generators/dynamodb/devise_generator'

module AwsRecord
  module Generators
    # `rails generate devise User` when the application's generator ORM is
    # :aws_record. Same as `dynamodb:devise --library=aws_record`.
    class DeviseGenerator < ::Dynamodb::Generators::DeviseGenerator
      source_root File.expand_path("../../dynamodb", __FILE__)

      no_tasks do
        def library
          "aws_record"
        end
      end
    end
  end
end
