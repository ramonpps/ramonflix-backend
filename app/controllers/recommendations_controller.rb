class RecommendationsController < ApplicationController
  require 'httparty'

  def random
    # 1. Escolhe um gênero aleatório
    genres = ['Action', 'Fantasy']
    selected_genre = genres.sample
    
    # 2. URL do catálogo de Top Filmes do Cinemeta para esse gênero
    url = "https://v3-cinemeta.strem.io/catalog/movie/top/genre=#{selected_genre}.json"

    begin
      response = HTTParty.get(url, timeout: 5)
      
      if response.success?
        movies = JSON.parse(response.body)['metas'] || []
        
        if movies.any?
          # 3. Pega um filme aleatório da lista
          random_movie = movies.sample
          
          # Retorna formatado para o Frontend
          render json: {
            imdb_id: random_movie['imdb_id'],
            title: random_movie['name'],
            type: 'movie',
            poster: random_movie['poster'],
            year: random_movie['releaseInfo'],
            description: random_movie['description']
          }
        else
          render json: { error: "Nenhum filme encontrado" }, status: 404
        end
      else
        render json: { error: "Erro no Cinemeta" }, status: 502
      end
    rescue => e
      puts "Erro na recomendação: #{e.message}"
      render json: { error: "Erro interno" }, status: 500
    end
  end
end