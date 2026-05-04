class TransactionCountPolicy < ApplicationPolicy
  def show? = user.present?
end
