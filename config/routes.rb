Rails.application.routes.draw do
# Rota para buscar filmes/séries (ex: /search?q=Batman)
  get '/search', to: 'search#index'
  get '/random', to: 'recommendations#random' # <--- NOVA ROTA
  
  # Rota para pegar os links processados (ex: /streams?imdb_id=tt123...)
  get '/streams', to: 'streams#index'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
