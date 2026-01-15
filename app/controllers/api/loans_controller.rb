module Api
  class LoansController < ActionController::API
    rescue_from ActionController::ParameterMissing, with: :bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from Loans::Borrow::NotAvailableError, with: :conflict

    def create
      loan = Loans::Borrow.call(
        item_id: params.require(:item_id),
        borrower_name: params.require(:borrower_name)
      )

      render json: loan.as_json(only: %i[id item_id borrower_name borrowed_at returned_at created_at updated_at]),
             status: :created
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
      render json: { error: "item_not_available" }, status: :conflict
    end
  end
end
