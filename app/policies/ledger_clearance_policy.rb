class LedgerClearancePolicy < ApplicationPolicy
  def new? = user.present?
  def create? = user.present?
end
