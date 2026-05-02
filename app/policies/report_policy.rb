class ReportPolicy < ApplicationPolicy
  def show? = user.present?
end
