class HomeController < ApplicationController
  require 'httparty'

  def index
    # Chave de Cache
    cache_key = "home_data_v5_religious_fixed"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      puts "\n⚡ [CACHE MISS] Construindo Home Page..."
      fetch_home_data_parallel
    end

    render json: json_result
  end

  private

  def fetch_home_data_parallel
    genres = [
      'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 
      'Documentary', 'Drama', 'Fantasy', 'Horror', 'Sci-Fi'
    ]
    
    base_url = "https://v3-cinemeta.strem.io/catalog/movie/top"
    data = {}
    hero_candidates = [] 

    threads = []

    # 1. Thread: Top Geral
    threads << Thread.new do
      data['Melhores Avaliados'] = fetch_and_process("#{base_url}.json", shuffle: false)
    end

    # 2. Thread: Fé e Espiritualidade (LÓGICA BLINDADA)
    threads << Thread.new do
      # A) Busca por termos específicos na API (Garante volume)
      terms = %w[Jesus Bible Gospel Christ God Faith]
      searched_movies = []
      
      terms.each do |term|
        res = fetch_raw("#{base_url}/search=#{term}.json")
        searched_movies.concat(res)
      end

      # B) Lista VIP de IDs (Garante qualidade - Clássicos Cristãos)
      # Paixão de Cristo, Quarto de Guerra, Deus Não Está Morto, A Cabana, Milagres do Paraíso, Até o Último Homem, etc.
      vip_ids = %w[tt0335345 tt3832914 tt2528814 tt2872518 tt4257926 tt2119532 tt3231054 tt7388562 tt0052618 tt1959490 tt1528100 tt2954690 tt9664228 tt1735232 tt1230442]
      
      # Busca metadados dos VIPs em paralelo (rápido pois são poucos)
      vip_movies = []
      vip_ids.each do |vid|
        begin
           r = HTTParty.get("https://v3-cinemeta.strem.io/meta/movie/#{vid}.json", timeout: 2)
           vip_movies << JSON.parse(r.body)['meta'] if r.success?
        rescue; end
      end

      # C) Junta tudo, remove duplicatas e remove NATAL
      all_religious = (searched_movies + vip_movies).uniq { |m| m['imdb_id'] }
      
      # Filtro de Exclusão (Remove Grinch, Esqueceram de Mim, etc)
      filtered_religious = all_religious.reject do |m|
        title = m['name'].to_s.downcase
        desc = m['description'].to_s.downcase
        # Se tiver "Christmas", "Holiday" ou "Santa" e NÃO tiver "Jesus", remove.
        (title.include?('christmas') || title.include?('natal') || title.include?('grinch') || title.include?('home alone')) && !desc.include?('jesus')
      end

      # Processa e traduz
      processed = process_items(filtered_religious, shuffle: true)
      data['Fé e Espiritualidade'] = processed
    end

    # 3. Threads: Gêneros Padrão
    genres.each do |genre|
      threads << Thread.new do
        genre_pt = translate_genre(genre)
        items = fetch_and_process("#{base_url}/genre=#{genre}.json", shuffle: true)
        data[genre_pt] = items

        if ['Action', 'Adventure', 'Crime'].include?(genre)
          hero_candidates.concat(items)
        end
      end
    end

    threads.each(&:join)

    hero_movie = hero_candidates.select { |m| m[:poster].present? }.sample

    {
      hero: hero_movie,
      catalogs: data
    }
  end

  # --- Helpers ---

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
    # Aceita qualquer nota para religiosos (pois alguns não tem rating alto no IMDB geral)
    valid_items = raw_items.select do |m| 
      m['poster'].present? # Garante que tem poster
    end

    list = shuffle ? valid_items.shuffle : valid_items

    list.take(15).map do |m|
      {
        imdb_id: m['imdb_id'],
        title: translate_google(m['name']),
        original_title: m['name'],
        poster: m['poster'],
        type: 'movie',
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