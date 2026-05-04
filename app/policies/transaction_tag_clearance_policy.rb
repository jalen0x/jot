class TransactionTagClearancePolicy < ApplicationPolicy
  def create? = user.present?
end
