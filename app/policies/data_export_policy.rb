class DataExportPolicy < ApplicationPolicy
  def create? = user.present?
end
