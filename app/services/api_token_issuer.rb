class ApiTokenIssuer
  def issue(user:, attributes:)
    attributes = attributes.to_h.symbolize_keys
    raw_token = SecureRandom.urlsafe_base64(32)
    api_token = user.api_tokens.build(
      name: attributes[:name],
      token_digest: BCrypt::Password.create(raw_token),
      expires_at: expires_at(attributes[:expires_in_days])
    )

    issued = api_token.save
    Result.new(issued: issued, api_token: api_token, raw_token: issued ? raw_token : nil)
  end

  private

  def expires_at(expires_in_days)
    days = expires_in_days.to_i
    return if days <= 0

    days.days.from_now
  end

  class Result
    attr_reader :api_token, :raw_token

    def initialize(issued:, api_token:, raw_token:)
      @issued = issued
      @api_token = api_token
      @raw_token = raw_token
    end

    def issued? = @issued
  end
end
