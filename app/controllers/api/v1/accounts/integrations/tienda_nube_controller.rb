class Api::V1::Accounts::Integrations::TiendaNubeController < Api::V1::Accounts::BaseController
  include TiendaNube::IntegrationHelper
  before_action :fetch_hook, except: [:auth]
  before_action :validate_contact, only: [:orders]

  def auth
    return render json: { error: 'Client ID is not configured' }, status: :unprocessable_entity if client_id.blank?

    state = generate_tienda_nube_token(Current.account.id)
    return render json: { error: 'Client secret is not configured' }, status: :unprocessable_entity if state.blank?

    auth_url = "https://www.tiendanube.com/apps/#{client_id}/authorize?"
    auth_url += URI.encode_www_form(
      client_id: client_id,
      response_type: 'code',
      state: state
    )

    render json: { redirect_url: auth_url }
  end

  def orders
    customers = fetch_customers
    return render json: { orders: [] } if customers.empty?

    orders = fetch_orders(customers.first['id'])
    render json: { orders: orders }
  rescue StandardError => e
    Rails.logger.error("Tienda Nube orders error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def contact
    @contact ||= Current.account.contacts.find_by(id: params[:contact_id])
  end

  def fetch_hook
    @hook = Integrations::Hook.find_by!(account: Current.account, app_id: 'tienda_nube')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Tienda Nube integration not found' }, status: :not_found
  end

  def validate_contact
    return unless contact.blank? || (contact.email.blank? && contact.phone_number.blank?)

    render json: { error: 'Contact information missing' }, status: :unprocessable_entity
  end

  def api_base_url
    "https://api.tiendanube.com/v1/#{@hook.reference_id}"
  end

  def api_headers
    {
      'Authentication' => "bearer #{@hook.access_token}",
      'Content-Type' => 'application/json',
      'User-Agent' => 'Chatwoot (support@chatwoot.com)'
    }
  end

  def fetch_customers
    queries = []
    queries << contact.email if contact.email.present?
    queries << contact.phone_number if contact.phone_number.present?

    customers = []

    # Search by email first, then phone — TN doesn't support OR queries
    queries.each do |query|
      result = tienda_nube_get('/customers', { q: query, fields: 'id,name,email,phone' })
      customers = result if result.any?
      break if customers.any?
    end

    customers
  end

  def fetch_orders(customer_id)
    orders = tienda_nube_get(
      '/orders',
      {
        customer_ids: customer_id,
        fields: 'id,number,status,payment_status,created_at,total,currency'
      }
    )

    store_domain = @hook.settings['store_domain']
    orders.map do |order|
      order.merge(
        'admin_url' => store_domain ? "https://#{store_domain}/admin/orders/#{order['id']}" : nil
      )
    end
  end

  def tienda_nube_get(path, params)
    uri = URI("#{api_base_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    response = execute_get(uri)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("Tienda Nube API error (#{path}): HTTP #{response.code} #{response.body}")
      return []
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Tienda Nube API error (#{path}): #{e.message}")
    []
  end

  def execute_get(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    api_headers.each { |k, v| request[k] = v }
    http.request(request)
  end
end
