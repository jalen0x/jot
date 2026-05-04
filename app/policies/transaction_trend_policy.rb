class TransactionTrendPolicy < ApplicationPolicy
  def index? = user.present?
end
