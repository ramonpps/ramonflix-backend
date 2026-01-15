class HomeController < ApplicationController
  require 'httparty'

  def index
    # Lista de gêneros para buscar no Cinemeta
    genres = [
      'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 
      'Documentary', 'Drama', 'Fantasy', 'Horror', 
      'Mystery', 'Sci-Fi', 'Thriller'
    ]

    # URLs base
    base_url = "https://v3-cinemeta.strem.io/catalog/movie/top"
    
    data = {}
    hero_candidates = [] # Lista para sortear o Hero (Ação/Aventura/Crime)

    threads = []

    # 1. Busca TOP RATED (Ordenado por nota, sem shuffle)
    threads << Thread.new do
      url = "#{base_url}.json"
      items = fetch_and_process(url, shuffle: false)
      data['Melhores Avaliados'] = items
    end

    # 2. Busca GÊNEROS (Aleatório > 6.0)
    genres.each do |genre|
      threads << Thread.new do
        url = "#{base_url}/genre=#{genre}.json"
        # Traduz o nome do gênero para a chave do JSON
        genre_pt = translate_genre(genre)
        
        # Busca, filtra > 6, embaralha
        items = fetch_and_process(url, shuffle: true)
        data[genre_pt] = items

        # Se for Action, Adventure ou Crime, adiciona aos candidatos a Hero
        if ['Action', 'Adventure', 'Crime'].include?(genre)
          hero_candidates.concat(items)
        end
      end
    end

    threads.each(&:join)

    # 3. Escolhe o Hero
    # Pega um aleatório dos candidatos, garantindo que tenha poster de alta resolução
    hero_movie = hero_candidates.select { |m| m[:poster].present? }.sample

    render json: {
      hero: hero_movie,
      catalogs: data
    }
  end

  private

  def fetch_and_process(url, shuffle: true)
    begin
      res = HTTParty.get(url, timeout: 8)
      return [] unless res.success?

      raw_items = JSON.parse(res.body)['metas'] || []
      
      # Filtra filmes com nota > 6.0 (se disponível)
      valid_items = raw_items.select do |m| 
        rating = m['imdbRating'].to_f
        rating > 6.0 || m['imdbRating'].nil? # Aceita nil pra não zerar listas novas
      end

      # Se for catálogo de gênero, embaralha. Se for Top geral, mantém ordem.
      processed_list = shuffle ? valid_items.shuffle : valid_items

      # Pega os 15 primeiros e traduz
      processed_list.take(15).map do |m|
        {
          imdb_id: m['imdb_id'],
          title: translate_google(m['name']),
          original_title: m['name'],
          poster: m['poster'],
          type: 'movie',
          rating: m['imdbRating']
        }
      end
    rescue
      []
    end
  end

  def translate_genre(genre)
    map = {
      'Action' => 'Ação', 'Adventure' => 'Aventura', 'Animation' => 'Animação',
      'Comedy' => 'Comédia', 'Crime' => 'Policial', 'Documentary' => 'Documentário',
      'Drama' => 'Drama', 'Fantasy' => 'Fantasia', 'Horror' => 'Terror',
      'Mystery' => 'Mistério', 'Sci-Fi' => 'Ficção Científica', 'Thriller' => 'Suspense'
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