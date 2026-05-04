class TransactionPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owns_record?
  def new? = create?
  def create? = user.present?
  def update? = owns_record?
  def destroy? = owns_record?
  def batch_delete? = user.present?
  def batch_update_category? = user.present?
  def batch_add_tags? = user.present?
  def batch_remove_tags? = user.present?
  def batch_clear_tags? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def owns_record? = user.present? && record.user_id == user.id
end
