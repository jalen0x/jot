class TransactionTagRemovalPolicy < ApplicationPolicy
  def create? = user.present?
end
