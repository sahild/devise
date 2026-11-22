# frozen_string_literal: true

# Entry point for DynamoDB support. Picks the modelling library configured in
# `Devise.dynamodb_library` (:dynamoid by default, or :aws_record):
#
#   Devise.setup do |config|
#     config.dynamodb_library = :dynamoid # or :aws_record
#     require 'devise/orm/dynamodb'
#   end
#
# You can also require a specific library adapter directly with
# `require 'devise/orm/dynamoid'` or `require 'devise/orm/aws_record'`.
module Devise
  module Orm
    module Dynamodb
      LIBRARIES = {
        dynamoid: "devise/orm/dynamoid",
        aws_record: "devise/orm/aws_record"
      }.freeze

      def self.library_path(library)
        LIBRARIES.fetch(library.to_s.tr("-", "_").to_sym) do
          raise ArgumentError, "Unsupported Devise.dynamodb_library #{library.inspect}. " \
            "Supported values are: #{LIBRARIES.keys.map(&:inspect).join(", ")}."
        end
      end
    end
  end
end

require Devise::Orm::Dynamodb.library_path(Devise.dynamodb_library)
