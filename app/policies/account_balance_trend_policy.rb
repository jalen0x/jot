class AccountBalanceTrendPolicy < ApplicationPolicy
  def index? = user.present?
end
