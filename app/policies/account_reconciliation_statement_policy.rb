class AccountReconciliationStatementPolicy < ApplicationPolicy
  def show? = user.present?
end
