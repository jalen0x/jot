class ImportBatchPolicy < ApplicationPolicy
  def show? = user.present? && record.user_id == user.id
  def new? = create?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
