module Api
  class ReturnsController < ActionController::API
    rescue_from ActionController::ParameterMissing, with: :bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from Loans::Return::NotBorrowedError, with: :conflict

    def create
      loan = Loans::Return.call(item_id: params.require(:item_id))
      render json: loan.as_json(only: %i[id item_id borrower_name borrowed_at returned_at created_at updated_at]), status: :ok
    end

    private

    def bad_request(e)
      render json: { error: "bad_request", message: e.message }, status: :bad_request
    end

    def not_found(e)
      render json: { error: "not_found", message: e.message }, status: :not_found
    end

    def unprocessable_entity(e)
      render json: { error: "validation_error", message: e.record.errors.full_messages.join(", ") },
             status: :unprocessable_entity
    end

    def conflict(_e)
      render json: { error: "item_not_borrowed" }, status: :conflict
    end
  end
end
