class RecommendationsController < ApplicationController
  require 'httparty'

  def random
    # Pega o gênero da URL ou escolhe um padrão
    genre_param = params[:genre]
    selected_genre = genre_param.present? ? genre_param : ['Action', 'Fantasy'].sample
    
    # URL do catálogo
    url = "https://v3-cinemeta.strem.io/catalog/movie/top/genre=#{selected_genre}.json"

    begin
      response = HTTParty.get(url, timeout: 5)
      
      if response.success?
        movies = JSON.parse(response.body)['metas'] || []
        
        if movies.any?
          random_movie = movies.sample
          
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