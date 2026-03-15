class TiendaNube::CallbacksController < ApplicationController
  include TiendaNube::IntegrationHelper

  def show
    verify_account!

    response = exchange_code_for_token

    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("Tienda Nube callback error: #{e.message}")
    redirect_to "#{tienda_nube_integration_url(account)}?error=true", allow_other_host: true
  end

  private

  def verify_account!
    @account_id = verify_tienda_nube_token(params[:state])
    raise StandardError, 'Invalid state parameter' if account.blank?
  end

  def exchange_code_for_token
    uri = URI('https://www.tiendanube.com/apps/authorize/token')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      client_id: client_id,
      client_secret: client_secret,
      grant_type: 'authorization_code',
      code: params[:code]
    }.to_json

    response = http.request(request)
    raise StandardError, "Token exchange failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def handle_response(parsed_body)
    account.hooks.create!(
      app_id: 'tienda_nube',
      access_token: parsed_body['access_token'],
      status: 'enabled',
      # store_id (user_id) is required for all Tienda Nube API calls
      reference_id: parsed_body['user_id'].to_s
    )

    redirect_to tienda_nube_integration_url(account), allow_other_host: true
  end

  def account
    @account ||= Account.find_by(id: @account_id)
  end

  def tienda_nube_integration_url(acc)
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{acc.id}/settings/integrations/tienda_nube"
  end
end
