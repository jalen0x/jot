class HomeController < ApplicationController
  def show
    redirect_to user_signed_in? ? edit_user_registration_path : new_user_session_path
  end
end
