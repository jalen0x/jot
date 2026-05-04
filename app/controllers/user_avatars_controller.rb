class UserAvatarsController < ApplicationController
  before_action :authenticate_user!

  # POST /user_avatar
  def create
    authorize :user_avatar
    current_user.avatar.attach(avatar_attachable)

    redirect_to user_profile_path, notice: t(".updated")
  end

  # DELETE /user_avatar
  def destroy
    authorize :user_avatar
    current_user.avatar.purge if current_user.avatar.attached?

    redirect_to user_profile_path, notice: t(".removed"), status: :see_other
  end

  private

  def avatar_attachable
    file = params.expect(:avatar)
    return file unless file.respond_to?(:tempfile)

    {
      io: file.tempfile,
      filename: file.original_filename,
      content_type: file.content_type,
      identify: false
    }
  end
end
