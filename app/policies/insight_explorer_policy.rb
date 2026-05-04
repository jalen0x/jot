class InsightExplorerPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = user.present? && record.user_id == user.id
  def create? = user.present?
  def update? = user.present? && record.user_id == user.id
  def destroy? = user.present? && record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
