class TransactionCategoryPolicy < ApplicationPolicy
  def index? = user.present?
  def new? = create?
  def create? = user.present?
  def update? = owns_record?
  def destroy? = owns_record?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def owns_record? = user.present? && record.user_id == user.id
end
