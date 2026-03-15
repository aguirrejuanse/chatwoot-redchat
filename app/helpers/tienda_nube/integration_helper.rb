module TiendaNube::IntegrationHelper
  REQUIRED_SCOPES = %w[read_orders read_customers].freeze

  def generate_tienda_nube_token(account_id)
    return if client_secret.blank?

    JWT.encode(token_payload(account_id), client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate Tienda Nube token: #{e.message}")
    nil
  end

  def verify_tienda_nube_token(token)
    return if token.blank? || client_secret.blank?

    decode_token(token, client_secret)
  end

  private

  def token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  def client_id
    @client_id ||= GlobalConfigService.load('TIENDA_NUBE_CLIENT_ID', nil)
  end

  def client_secret
    @client_secret ||= GlobalConfigService.load('TIENDA_NUBE_CLIENT_SECRET', nil)
  end

  def decode_token(token, secret)
    JWT.decode(token, secret, true, algorithm: 'HS256').first['sub']
  rescue JWT::DecodeError => e
    Rails.logger.error("Unexpected error verifying Tienda Nube token: #{e.message}")
    nil
  end
end
