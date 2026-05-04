class TransactionDeletionPolicy < ApplicationPolicy
  def create? = user.present?
end
