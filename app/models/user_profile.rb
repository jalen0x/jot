class UserProfile
  delegate :email, :first_name, :last_name, :name, :avatar, :errors, to: :user

  def initialize(user)
    @user = user
  end

  def update(attributes)
    user.update(attributes)
  end

  def as_json(_options = {})
    {
      email: email,
      first_name: first_name,
      last_name: last_name,
      name: name.to_s,
      avatar_attached: avatar.attached?
    }
  end

  private

  attr_reader :user
end
