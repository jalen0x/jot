class UserAvatarPolicy < ApplicationPolicy
  def create? = user.present?
  def destroy? = user.present?
end
