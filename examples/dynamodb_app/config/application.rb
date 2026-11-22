require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

# :dynamoid (default) or :aws_record. Each library keeps its models in its own
# directory so both variants of the app can live side by side.
DYNAMODB_LIBRARY = ENV.fetch("DYNAMODB_LIBRARY", "dynamoid").to_sym

module DynamodbApp
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_paths << root.join("app/models/#{DYNAMODB_LIBRARY}")
    config.eager_load_paths << root.join("app/models/#{DYNAMODB_LIBRARY}")
    Rails.autoloaders.main.ignore(*(%i[dynamoid aws_record] - [DYNAMODB_LIBRARY]).map { |lib| root.join("app/models/#{lib}") })

    config.generators do |g|
      g.orm :dynamodb
    end

    config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { "dynamodb-sample-app-not-secret-#{'x' * 64}" }
  end
end
