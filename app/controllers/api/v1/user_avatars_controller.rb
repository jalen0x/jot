class Api::V1::UserAvatarsController < ApiController
  # POST /api/v1/user_avatar
  def create
    authorize :user_avatar
    current_user.avatar.attach(avatar_attachable)

    render json: { user_profile: UserProfile.new(current_user) }, status: :created
  end

  # DELETE /api/v1/user_avatar
  def destroy
    authorize :user_avatar
    current_user.avatar.purge if current_user.avatar.attached?

    head :no_content
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
