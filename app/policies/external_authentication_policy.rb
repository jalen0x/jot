class ExternalAuthenticationPolicy < ApplicationPolicy
  def index? = user.present?
  def destroy? = user.present?
end
