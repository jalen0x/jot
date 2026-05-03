class ApiTokenPolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user.present?
  def destroy? = user.present? && record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
