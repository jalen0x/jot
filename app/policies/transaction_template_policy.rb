class TransactionTemplatePolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user.present?

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
