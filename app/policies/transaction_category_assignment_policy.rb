class TransactionCategoryAssignmentPolicy < ApplicationPolicy
  def create? = user.present?
end
