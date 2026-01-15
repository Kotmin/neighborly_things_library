module Api
  class ItemsController < ActionController::API
    def index
      items = Item.order(created_at: :desc)
      render json: items.as_json(only: %i[id name category description condition available created_at updated_at])
    end

    def create
      item = Item.create!(item_params)
      render json: item.as_json(only: %i[id name category description condition available created_at updated_at]), status: :created
    end

    private

    def item_params
      params.require(:item).permit(:name, :category, :description, :condition)
    end
  end
end