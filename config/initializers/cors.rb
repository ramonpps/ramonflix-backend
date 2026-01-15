Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*' # Em produção, troque '*' pelo domínio do seu site
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end