# frozen_string_literal: true

unless defined?(DEVISE_ORM)
  DEVISE_ORM = (ENV["DEVISE_ORM"] || :active_record).to_sym
end

module Devise
  module Test
    # Detection for minor differences between Rails versions in tests.

    def self.rails71_and_up?
      !rails70? && Rails::VERSION::MAJOR >= 7
    end

    def self.rails70_and_up?
      Rails::VERSION::MAJOR >= 7
    end

    def self.rails70?
      Rails.version.start_with? '7.0'
    end

    # DEVISE_ORM=dynamoid or DEVISE_ORM=aws_record run the suite against
    # Amazon DynamoDB (devise/orm/dynamodb) using that library.
    def self.dynamodb?
      [:dynamoid, :aws_record].include?(DEVISE_ORM)
    end
  end
end

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
