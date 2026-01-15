module Api
  class ReturnsController < ActionController::API
    rescue_from Loans::Return::NotBorrowedError, with: :conflict

    def create
      loan = Loans::Return.call(item_id: params.require(:item_id))
      render json: loan.as_json(only: %i[id item_id borrower_name borrowed_at returned_at created_at updated_at]), status: :ok
    end

    private

    def conflict(_e)
      render json: { error: "item_not_borrowed" }, status: :conflict
    end
  end
end