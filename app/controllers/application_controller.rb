class ApplicationController < ActionController::API
  before_action :set_locale

  include Errors::ErrorHandler

  private

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

  def generate_auth_token(user)
    payload = { email: user.email, role: user.role&.name }
    JwtToken::JwtToken.encode(payload)
  end

  def attach_auth_token(token)
    response.set_header("X-Access-Token", token)
  end

  def must_be_logged_in!
    payload_opts =
      begin
        JwtToken::JwtToken.decode(request.headers[access_header])
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

    return unauthorized! if payload_opts.nil?

    user_info = payload_opts[0]
    @current_user = User.find_by(email: user_info["email"])
    unauthorized! if @current_user.nil?
  end

  def must_be_admin!
    forbidden! unless @current_user&.role && @current_user.role != "admin"
  end

  def access_header
    "HTTP_X_ACCESS_TOKEN"
  end

  def render_resource(resource, status = :ok)
    render json: resource, status: status
  end

  def invalid_credentials!
    render json: {
      status: I18n.t("errors.unauthorized.status"),
      title: I18n.t("errors.unauthorized.title"),
      detail: I18n.t("errors.unauthorized.detail"),
      errors: [I18n.t("errors.invalid_credentials.error_message")]
    }, status: :unauthorized
  end

  def unauthorized!
    render json: {
        status: I18n.t("errors.unauthorized.status"),
        title: I18n.t("errors.unauthorized.title"),
        detail: I18n.t("errors.unauthorized.detail"),
        errors: [I18n.t("errors.unauthorized.error_message")]
    }, status: :unauthorized
  end

  def forbidden!
    render json: {
      status: I18n.t("errors.forbidden.status"),
      title: I18n.t("errors.forbidden.title"),
      detail: I18n.t("errors.forbidden.detail"),
      errors: [I18n.t("errors.forbidden.error_message")]
    }, status: :forbidden
  end

  def parameter_missing!(error)
    render json: {
      status: I18n.t("errors.parameter_missing.status"),
      title: I18n.t("errors.parameter_missing.title"),
      detail: I18n.t("errors.parameter_missing.detail"),
      errors: error
    }, status: :bad_request
  end

  def resource_invalid!(resource)
    render json: {
        status: I18n.t("errors.unprocessable_entity.status"),
        title: I18n.t("errors.unprocessable_entity.title"),
        detail: I18n.t("errors.unprocessable_entity.detail"),
        errors: resource.errors
    }, status: :unprocessable_entity
  end
end
