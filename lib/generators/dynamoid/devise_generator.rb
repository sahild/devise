# frozen_string_literal: true

require 'generators/dynamodb/devise_generator'

module Dynamoid
  module Generators
    # `rails generate devise User` when the application's generator ORM is
    # :dynamoid. Same as `dynamodb:devise --library=dynamoid`.
    class DeviseGenerator < ::Dynamodb::Generators::DeviseGenerator
      source_root File.expand_path("../../dynamodb", __FILE__)

      no_tasks do
        def library
          "dynamoid"
        end
      end
    end
  end
end
