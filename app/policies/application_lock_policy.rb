class ApplicationLockPolicy < ApplicationPolicy
  def show? = user.present?
  def create? = user.present?
  def lock? = user.present?
  def unlock? = user.present?
  def destroy? = user.present? && (record == :application_lock || record.user_id == user.id)
end
