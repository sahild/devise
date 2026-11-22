# frozen_string_literal: true

module Devise
  module Orm # :nodoc:
    def self.active_record?(model)
      defined?(ActiveRecord) && model < ActiveRecord::Base
    end

    # True for models backed by DynamoDB through one of the supported
    # libraries (Dynamoid or aws-record). The library adapters are only
    # defined once `devise/orm/dynamoid` or `devise/orm/aws_record` is loaded.
    def self.dynamodb?(model)
      (defined?(Devise::Orm::DynamoidSupport) && Devise::Orm::DynamoidSupport.model?(model)) ||
        (defined?(Devise::Orm::AwsRecordSupport) && Devise::Orm::AwsRecordSupport.model?(model)) ||
        false
    end

    def self.included(model)
      if Devise::Orm.active_record?(model)
        model.include DirtyTrackingActiveRecordMethods
      elsif Devise::Orm.dynamodb?(model)
        model.include DirtyTrackingDynamodbMethods
      else
        model.include DirtyTrackingMongoidMethods
      end
    end

    module DirtyTrackingActiveRecordMethods
      def devise_email_before_last_save
        email_before_last_save
      end

      def devise_email_in_database
        email_in_database
      end

      def devise_saved_change_to_email?
        saved_change_to_email?
      end

      def devise_saved_change_to_encrypted_password?
        saved_change_to_encrypted_password?
      end

      def devise_will_save_change_to_email?
        will_save_change_to_email?
      end

      def devise_unconfirmed_email_will_change!
        unconfirmed_email_will_change!
      end

      def devise_respond_to_and_will_save_change_to_attribute?(attribute)
        respond_to?("will_save_change_to_#{attribute}?") && send("will_save_change_to_#{attribute}?")
      end
    end

    module DirtyTrackingMongoidMethods
      def devise_email_before_last_save
        respond_to?(:email_previously_was) ? email_previously_was : email_was
      end

      def devise_email_in_database
        email_was
      end

      def devise_saved_change_to_email?
        respond_to?(:email_previously_changed?) ? email_previously_changed? : email_changed?
      end

      def devise_saved_change_to_encrypted_password?
        respond_to?(:encrypted_password_previously_changed?) ? encrypted_password_previously_changed? : encrypted_password_changed?
      end

      def devise_will_save_change_to_email?
        email_changed?
      end

      def devise_unconfirmed_email_will_change!
        # Mongoid's will_change! doesn't force unchanged attributes into updates,
        # so we override changed_attributes to make it see a difference.
        unconfirmed_email_will_change!
        changed_attributes["unconfirmed_email"] = nil
      end

      def devise_respond_to_and_will_save_change_to_attribute?(attribute)
        respond_to?("#{attribute}_changed?") && send("#{attribute}_changed?")
      end
    end

    # Shared by the Dynamoid and aws-record adapters. Each library support
    # module (Devise::Orm::DynamoidSupport / Devise::Orm::AwsRecordSupport)
    # implements these primitives:
    #
    #   devise_attribute_will_save_change?(attr)  - pending, unsaved change
    #   devise_attribute_in_database(attr)        - value currently persisted
    #   devise_attribute_saved_change?(attr)      - changed by the last save
    #   devise_attribute_before_last_save(attr)   - value before the last save
    #   devise_attribute_force_change!(attr)      - persist attr on next save
    #
    # "Last save" answers must be correct both inside after_create /
    # after_update callbacks and after #save has returned, because Devise
    # sends its notifications from after_update callbacks.
    module DirtyTrackingDynamodbMethods
      def devise_email_before_last_save
        devise_attribute_before_last_save(:email)
      end

      def devise_email_in_database
        devise_attribute_in_database(:email)
      end

      def devise_saved_change_to_email?
        devise_attribute_saved_change?(:email)
      end

      def devise_saved_change_to_encrypted_password?
        devise_attribute_saved_change?(:encrypted_password)
      end

      def devise_will_save_change_to_email?
        devise_attribute_will_save_change?(:email)
      end

      def devise_unconfirmed_email_will_change!
        # Force unconfirmed_email into the next write even when its value is
        # unchanged, to prevent the race condition fixed in #5783.
        devise_attribute_force_change!(:unconfirmed_email)
      end

      def devise_respond_to_and_will_save_change_to_attribute?(attribute)
        # Interpolate like the AR/Mongoid versions: with Hash authentication_keys
        # Devise passes [key, required] pairs, which must answer false, not raise.
        respond_to?("#{attribute}") && devise_attribute_will_save_change?(attribute)
      end
    end
  end
end
