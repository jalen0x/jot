class ExternalAuthentication
  attr_reader :provider

  def self.for_user(user)
    return [] if user.provider.blank?

    [ new(provider: user.provider) ]
  end

  def self.find_for_user!(user, id)
    for_user(user).find { |external_authentication| external_authentication.to_param == id.to_s } ||
      raise(ActiveRecord::RecordNotFound)
  end

  def initialize(provider:)
    @provider = provider.to_s
  end

  def id = provider
  def to_param = id

  def as_json(_options = {})
    {
      id: id,
      provider: provider
    }
  end
end
