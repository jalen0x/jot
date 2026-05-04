class DataStatisticsPolicy < ApplicationPolicy
  def show? = user.present?
end
