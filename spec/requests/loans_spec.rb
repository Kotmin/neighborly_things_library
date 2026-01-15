require "rails_helper"

RSpec.describe "Loans", type: :request do
  it "borrows an available item" do
    item = create(:item, available: true)

    post "/api/loans", params: { item_id: item.id, borrower_name: "Alice" }

    expect(response).to have_http_status(:created)
    expect(item.reload.available).to be(false)
  end

  it "rejects borrowing an unavailable item" do
    item = create(:item, available: false)

    post "/api/loans", params: { item_id: item.id, borrower_name: "Bob" }

    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body)).to include("error" => "item_not_available")
  end

  it "returns an item" do
    item = create(:item, available: true)
    post "/api/loans", params: { item_id: item.id, borrower_name: "Carol" }
    expect(response).to have_http_status(:created)

    post "/api/returns", params: { item_id: item.id }
    expect(response).to have_http_status(:ok)
    expect(item.reload.available).to be(true)
  end
end
