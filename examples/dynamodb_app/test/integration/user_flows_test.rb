require "test_helper"

# Walks through the seven Devise modules end to end against DynamoDB.
class UserFlowsTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  def sign_up(email, password = "password123")
    post user_registration_path, params: {
      user: { email: email, password: password, password_confirmation: password }
    }
  end

  def sign_in(email, password = "password123", remember: false)
    post user_session_path, params: {
      user: { email: email, password: password, remember_me: remember ? "1" : "0" }
    }
  end

  def last_token(param)
    ActionMailer::Base.deliveries.last.body.to_s[/#{param}=([^"&]+)/, 1]
  end

  def confirmed_user(email = "alice@example.com")
    sign_up(email)
    get user_confirmation_path(confirmation_token: last_token("confirmation_token"))
    User.find_for_authentication(email: email)
  end

  test "sign up sends a confirmation email and confirming allows sign in" do
    sign_up("alice@example.com")
    assert_equal ["alice@example.com"], ActionMailer::Base.deliveries.last.to

    sign_in("alice@example.com")
    assert_redirected_to new_user_session_path # unconfirmed

    get user_confirmation_path(confirmation_token: last_token("confirmation_token"))
    sign_in("alice@example.com")
    assert_redirected_to root_path

    get dashboard_path
    assert_response :success
  end

  test "email uniqueness is case insensitive like ActiveRecord" do
    sign_up("bob@example.com")
    sign_up("BOB@example.com")
    assert_response :unprocessable_entity
    assert_match "has already been taken", response.body
  end

  test "trackable records sign ins" do
    confirmed_user
    sign_in("alice@example.com")
    user = User.find_for_authentication(email: "alice@example.com")
    assert_equal 1, user.sign_in_count
    assert_equal "127.0.0.1", user.current_sign_in_ip
  end

  test "lockable locks after too many failed attempts and unlocks by email" do
    confirmed_user
    Devise.maximum_attempts.times { sign_in("alice@example.com", "wrong-password") }
    user = User.find_for_authentication(email: "alice@example.com")
    assert user.access_locked?

    get user_unlock_path(unlock_token: last_token("unlock_token"))
    assert_not User.find_for_authentication(email: "alice@example.com").access_locked?
  end

  test "recoverable resets the password" do
    confirmed_user
    post user_password_path, params: { user: { email: "alice@example.com" } }
    patch user_password_path, params: {
      user: { reset_password_token: last_token("reset_password_token"),
              password: "newpassword1", password_confirmation: "newpassword1" }
    }
    delete destroy_user_session_path
    sign_in("alice@example.com", "newpassword1")
    assert_redirected_to root_path
  end

  test "rememberable sets a remember cookie" do
    confirmed_user
    sign_in("alice@example.com", remember: true)
    assert cookies["remember_user_token"].present?
    assert User.find_for_authentication(email: "alice@example.com").remember_created_at
  end

  test "changing the email requires reconfirmation" do
    user = confirmed_user
    sign_in("alice@example.com")
    put user_registration_path, params: {
      user: { email: "alice.new@example.com", current_password: "password123" }
    }
    user = User.to_adapter.get(user.id)
    assert_equal "alice@example.com", user.email
    assert_equal "alice.new@example.com", user.unconfirmed_email

    get user_confirmation_path(confirmation_token: last_token("confirmation_token"))
    assert_equal "alice.new@example.com", User.to_adapter.get(user.id).email
  end
end
