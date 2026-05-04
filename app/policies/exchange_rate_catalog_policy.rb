class ExchangeRateCatalogPolicy < ApplicationPolicy
  def show? = user.present?
end
