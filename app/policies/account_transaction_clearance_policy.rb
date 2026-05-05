class AccountTransactionClearancePolicy < ApplicationPolicy
  def create? = user.present?
end
