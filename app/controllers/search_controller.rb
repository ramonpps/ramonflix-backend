class SearchController < ApplicationController
  require 'httparty'
  require 'uri'

  def index
    query = params[:q]
    
    # Retorna vazio se não tiver busca
    if query.blank?
      return render json: { results: [] }
    end

    # Codifica espaços e acentos (Corrige o URI Error)
    encoded_query = URI.encode_www_form_component(query)

    # Vamos buscar em DUAS fontes oficiais do Stremio (Filmes e Séries)
    # para garantir que você ache tudo, mesmo sem chave de API.
    url_movies = "https://v3-cinemeta.strem.io/catalog/movie/top/search=#{encoded_query}.json"
    url_series = "https://v3-cinemeta.strem.io/catalog/series/top/search=#{encoded_query}.json"

    begin
      # Dispara as duas buscas ao mesmo tempo (Threads)
      # Isso faz a busca ser muito rápida
      threads = []
      results_movies = []
      results_series = []

      threads << Thread.new do
        res = HTTParty.get(url_movies, timeout: 5)
        results_movies = JSON.parse(res.body)['metas'] || [] if res.success?
      end

      threads << Thread.new do
        res = HTTParty.get(url_series, timeout: 5)
        results_series = JSON.parse(res.body)['metas'] || [] if res.success?
      end

      threads.each(&:join) # Espera acabar

      # Junta tudo
      all_results = results_movies + results_series

      # Formata para o seu Frontend
      formatted_results = all_results.map do |item|
        {
          imdb_id: item['imdb_id'],
          title: item['name'],       # Cinemeta retorna em Inglês, mas é estável
          type: item['type'],
          year: item['releaseInfo'],
          poster: item['poster'],
          # Background opcional para deixar bonito se quiser usar depois
          background: item['background'] 
        }
      end

      # Remove itens sem poster (geralmente lixo)
      final_list = formatted_results.select { |i| i[:poster].present? }

      render json: { results: final_list }

    rescue => e
      puts "❌ ERRO GERAL: #{e.message}"
      # Em caso de erro grave, retorna lista vazia para não quebrar o frontend
      render json: { results: [] }
    end
  end
end