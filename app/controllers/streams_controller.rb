class StreamsController < ApplicationController
  require 'httparty'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type]
    season = params[:season]
    episode = params[:episode]
    title_hint = params[:title_hint]

    # Cache de 12 horas para ser instantâneo na segunda vez
    cache_key = "stream_data_v2/#{imdb_id}/#{type}/#{season}/#{episode}"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      puts "\n⚡ [CACHE MISS] Buscando dados frescos para #{imdb_id}..."
      fetch_data_parallel(imdb_id, type, season, episode, title_hint)
    end

    render json: json_result
  end

  private

  def fetch_data_parallel(imdb_id, type, season, episode, title_hint)
    meta_data = {}
    streams_br = []
    streams_global = []

    # Thread 1: Metadados + Tradução
    t_meta = Thread.new do
      begin
        url_meta = "https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json"
        meta_response = HTTParty.get(url_meta, timeout: 4)
        
        if meta_response.success?
          data = JSON.parse(meta_response.body)['meta']
          original_title = data['name']
          original_desc = data['description']
          
          translated_title = translate_google(original_title) 
          translated_desc = translate_google(original_desc)

          meta_data = {
            name: translated_title,         
            original_name: original_title,  
            description: translated_desc,   
            imdbRating: data['imdbRating'],
            cast: data['cast'] || [],
            director: data['director'], # <--- CAMPO NOVO ADICIONADO
            poster: data['poster'],
            background: data['background'],
            year: data['releaseInfo']
          }
        end
      rescue => e
        meta_data = { name: URI.decode_www_form_component(title_hint || "") }
      end
    end

    stream_id = (type == 'series') ? "#{imdb_id}:#{season}:#{episode}" : imdb_id
    
    # Thread 2: Busca BR
    t_br = Thread.new do
      begin
        br_providers = "comando,bludv,lapumia,wayup,nezu,ondebaixa"
        url = "https://torrentio.strem.fun/providers=#{br_providers}%7Clanguage=portuguese/stream/#{type}/#{stream_id}.json"
        res = HTTParty.get(url, timeout: 8) 
        streams_br = JSON.parse(res.body)['streams'] || [] if res.success?
      rescue
        streams_br = []
      end
    end

    # Thread 3: Busca Global
    t_global = Thread.new do
      begin
        url = "https://torrentio.strem.fun/sort=seeders%7Cqualityfilter=4k/stream/#{type}/#{stream_id}.json"
        res = HTTParty.get(url, timeout: 8)
        streams_global = JSON.parse(res.body)['streams'] || [] if res.success?
      rescue
        streams_global = []
      end
    end

    [t_meta, t_br, t_global].each(&:join)

    process_streams = lambda do |list, source_type|
      list.map do |stream|
        score = source_type == :br ? 20000 : 0
        if source_type == :global && meta_data[:original_name]
           score += 5000 
        end
        stream.merge('compatibility_score' => score)
      end
    end

    raw_dubbed = process_streams.call(streams_br, :br).select { |s| s['compatibility_score'] > 0 }
    raw_subtitled = process_streams.call(streams_global, :global).select { |s| s['compatibility_score'] > 0 }

    br_regex = /dublado|dual|nacional|pt-br|portugues/i
    raw_subtitled = raw_subtitled.reject { |s| s['title'].match?(br_regex) }

    {
      meta: meta_data,
      dubbed: raw_dubbed.map { |s| format_stream(s) },
      subtitled: raw_subtitled.map { |s| format_stream(s) }
    }
  end

  def format_stream(s)
    magnet_link = s['magnet'] || "magnet:?xt=urn:btih:#{s['infoHash']}"
    {
      magnet: magnet_link,
      title: s['title'] || "Sem Título",
      name: s['name'] || "Torrent",
      infoHash: s['infoHash'],
      score: s['compatibility_score']
    }
  end

  def translate_google(text)
    return text if text.blank?
    base_url = "https://translate.googleapis.com/translate_a/single"
    params = { client: "gtx", sl: "en", tl: "pt", dt: "t", q: text }
    begin
      response = HTTParty.get(base_url, query: params, timeout: 1.5)
      JSON.parse(response.body)[0].map { |part| part[0] }.join
    rescue
      text
    end
  end
end