class HomeController < ApplicationController
  before_action :authenticate_user!, only: :account

  def index
  end

  def account
  end
end
