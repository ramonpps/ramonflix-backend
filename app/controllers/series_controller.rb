class SeriesController < ApplicationController
  require 'httparty'

  def index
    cache_key = "series_home_data_v2_translated"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      fetch_series_data_parallel
    end

    render json: json_result
  end

  private

  def fetch_series_data_parallel
    base_url = "https://v3-cinemeta.strem.io/catalog/series/top"
    
    genres = [
      'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 
      'Documentary', 'Drama', 'Fantasy', 'Horror', 'Sci-Fi'
    ]
    
    data = {}
    hero_candidates = [] 
    threads = []

    # 1. Top Séries
    threads << Thread.new do
      data['Melhores Avaliadas'] = fetch_and_process("#{base_url}.json", shuffle: false)
    end

    # 2. Gêneros
    genres.each do |genre|
      threads << Thread.new do
        genre_pt = translate_genre(genre)
        url = "#{base_url}/genre=#{genre}.json"
        items = fetch_and_process(url, shuffle: true)
        data[genre_pt] = items

        if ['Action', 'Adventure', 'Crime', 'Sci-Fi'].include?(genre)
          hero_candidates.concat(items)
        end
      end
    end

    threads.each(&:join)

    hero_series = hero_candidates.select { |m| m[:poster].present? }.sample

    {
      hero: hero_series,
      catalogs: data
    }
  end

  def fetch_raw(url)
    begin
      res = HTTParty.get(url, timeout: 5)
      return [] unless res.success?
      JSON.parse(res.body)['metas'] || []
    rescue
      []
    end
  end

  def process_items(raw_items, shuffle: true)
    valid_items = raw_items.select { |m| m['poster'].present? }
    list = shuffle ? valid_items.shuffle : valid_items

    # Tradução em lote para as séries
    list.take(15).map do |m|
      {
        imdb_id: m['imdb_id'],
        title: translate_google(m['name']), # Traduz o título
        original_title: m['name'],
        poster: m['poster'],
        type: 'series',
        rating: m['imdbRating']
      }
    end
  end

  def fetch_and_process(url, shuffle: true)
    raw = fetch_raw(url)
    process_items(raw, shuffle: shuffle)
  end

  def translate_genre(genre)
    map = {
      'Action' => 'Ação', 'Adventure' => 'Aventura', 'Animation' => 'Animação',
      'Comedy' => 'Comédia', 'Crime' => 'Policial', 'Documentary' => 'Documentário',
      'Drama' => 'Drama', 'Fantasy' => 'Fantasia', 'Horror' => 'Terror',
      'Sci-Fi' => 'Ficção Científica'
    }
    map[genre] || genre
  end

  def translate_google(text)
    return text if text.blank?
    base_url = "https://translate.googleapis.com/translate_a/single"
    params = { client: "gtx", sl: "en", tl: "pt", dt: "t", q: text }
    begin
      response = HTTParty.get(base_url, query: params, timeout: 1)
      JSON.parse(response.body)[0].map { |part| part[0] }.join
    rescue
      text
    end
  end
end