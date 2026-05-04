class TransactionStatisticsPolicy < ApplicationPolicy
  def show? = user.present?
end
