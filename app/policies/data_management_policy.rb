class DataManagementPolicy < ApplicationPolicy
  def show? = user.present?
end
