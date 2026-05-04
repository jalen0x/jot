class SystemVersionPolicy < ApplicationPolicy
  def show? = user.present?
end
