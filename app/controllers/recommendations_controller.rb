class RecommendationsController < ApplicationController
  require 'httparty'

  def random
    genre_param = params[:genre]
    
    if genre_param == 'Religious'
      # --- LÓGICA ESPECIAL PARA RELIGIOSO ---
      
      # 1. Lista VIP (Garantia de acerto)
      vip_ids = %w[tt0335345 tt3832914 tt2528814 tt2872518 tt4257926 tt2119532 tt3231054 tt7388562 tt0052618 tt1959490 tt1528100 tt2954690 tt9664228 tt1735232 tt1230442]
      
      # Escolhe um ID aleatório da lista VIP
      random_id = vip_ids.sample
      
      # Busca os dados dele
      begin
        response = HTTParty.get("https://v3-cinemeta.strem.io/meta/movie/#{random_id}.json", timeout: 4)
        if response.success?
          movie = JSON.parse(response.body)['meta']
          return render json: format_movie(movie)
        end
      rescue; end
      
      # Se falhar o VIP (raro), cai no fallback genérico abaixo
    end

    # --- LÓGICA PADRÃO PARA OUTROS GÊNEROS ---
    search_genre = (genre_param == 'Religious') ? 'Drama' : (genre_param || 'Action')
    url = "https://v3-cinemeta.strem.io/catalog/movie/top/genre=#{search_genre}.json"

    begin
      response = HTTParty.get(url, timeout: 4)
      if response.success?
        movies = JSON.parse(response.body)['metas'] || []
        
        if movies.any?
          random_movie = movies.sample
          render json: format_movie(random_movie)
        else
          render json: { error: "Nada encontrado" }, status: 404
        end
      else
        render json: { error: "Erro Cinemeta" }, status: 502
      end
    rescue
      render json: { error: "Erro interno" }, status: 500
    end
  end

  private 

  def format_movie(m)
    {
      imdb_id: m['imdb_id'],
      title: m['name'],
      type: 'movie',
      poster: m['poster'],
      year: m['releaseInfo'],
      description: m['description']
    }
  end
end