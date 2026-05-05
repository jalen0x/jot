class ApiTokenClearancePolicy < ApplicationPolicy
  def create? = user.present?
end
