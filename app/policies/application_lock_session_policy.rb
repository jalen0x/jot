class ApplicationLockSessionPolicy < ApplicationPolicy
  def new? = user.present?
  def create? = user.present?
  def destroy? = user.present?
end
