# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Permite localhost (teste) e o seu futuro dominio da Vercel
    origins 'localhost:5173', ENV['FRONTEND_URL'] || '*' 

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end