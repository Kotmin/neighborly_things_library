Rails.application.routes.draw do
  get "/healthz", to: "health#show"

  namespace :api do
    resources :items, only: %i[index create]
    resources :loans, only: %i[create]
    post "/returns", to: "returns#create"
  end
end
