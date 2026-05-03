class TwoFactorAuthenticationPolicy < ApplicationPolicy
  def show? = user.present?
  def create? = user.present?
  def destroy? = user.present? && record.user_id == user.id
end
