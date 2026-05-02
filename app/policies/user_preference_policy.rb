class UserPreferencePolicy < ApplicationPolicy
  def show? = user.present?
  def update? = user.present?
end
