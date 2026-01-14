class HealthController < ActionController::API
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")
    render json: { status: "ok" }
  rescue StandardError => e
    render json: { status: "error", error: e.class.name }, status: :service_unavailable
  end
end
