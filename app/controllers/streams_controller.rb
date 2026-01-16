class StreamsController < ApplicationController
  require 'httparty'
  require 'uri'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type]
    season = params[:season]
    episode = params[:episode]
    title_hint = params[:title_hint]

    # Cache
    cache_key = "stream_portfolio_v1/#{imdb_id}/#{type}/#{season}/#{episode}"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      fetch_data_safe_mode(imdb_id, type, season, episode, title_hint)
    end

    render json: json_result
  end

  private

  def fetch_data_safe_mode(imdb_id, type, season, episode, title_hint)
    meta_data = {}

    # 1. BUSCA METADADOS REAIS (Para a interface ficar bonita)
    begin
      url_meta = "https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json"
      meta_response = HTTParty.get(url_meta, timeout: 5)
      
      if meta_response.success?
        data = JSON.parse(meta_response.body)['meta']
        
        # Traduções
        trans_title = translate_google(data['name']) 
        trans_desc = translate_google(data['description'])
        
        ep_title = nil
        ep_desc = nil
        
        # Se for série, busca dados do episódio real
        if type == 'series' && season.present?
           target = data['videos']&.find { |v| v['season'].to_s == season.to_s && v['episode'].to_s == episode.to_s }
           if target
              ep_title = translate_google(target['name'] || "Episódio #{episode}")
              ep_desc = translate_google(target['overview'] || target['description'])
           end
        end

        meta_data = {
          name: trans_title,         
          original_name: data['name'],  
          description: trans_desc,
          episode_title: ep_title, 
          episode_description: ep_desc,
          imdbRating: data['imdbRating'],
          cast: data['cast'] || [],
          director: data['director'],
          poster: data['poster'],
          background: data['background'],
          year: data['releaseInfo']
        }
      end
    rescue
      meta_data = { name: URI.decode_www_form_component(title_hint || "Desconhecido") }
    end

    # 2. GERAÇÃO DE STREAMS "SAFE" (Simulação)
    # Em vez de buscar no Torrentio, retornamos conteúdo Creative Commons
    
    label_suffix = type == 'series' ? "S#{season}E#{episode}" : "Filme Completo"
    
    # Lista de arquivos seguros para demonstração
    safe_streams = [
      {
        title: "⚡ Stream de Alta Velocidade (Demo: Sintel 4K)",
        name: "Servidor Principal 1",
        infoHash: "08ada5a7a6183aae1e09d831df6748d566095a10", # Sintel
        score: 10000
      },
      {
        title: "⚡ Stream Alternativo (Demo: Big Buck Bunny)",
        name: "Servidor Backup",
        infoHash: "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c", # Big Buck Bunny
        score: 5000
      }
    ]

    # Simulamos que existem opções Dubladas e Legendadas apontando para o conteúdo safe
    # Isso mantém a UI com os dois botões funcionais.
    
    dubbed_final = safe_streams.map { |s| format_stream(s, "DUBLADO - #{label_suffix}") }
    subtitled_final = safe_streams.map { |s| format_stream(s, "LEGENDADO - #{label_suffix}") }

    {
      meta: meta_data,
      dubbed: dubbed_final,
      subtitled: subtitled_final
    }
  end

  def format_stream(s, prefix)
    # Magnet Link Real do conteúdo Open Source
    magnet_link = "magnet:?xt=urn:btih:#{s[:infoHash]}&dn=Package&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337"
    {
      magnet: magnet_link,
      title: "#{prefix} | #{s[:title]}",
      name: s[:name],
      infoHash: s[:infoHash],
      score: s[:score]
    }
  end

  def translate_google(text)
    return text if text.blank?
    base_url = "https://translate.googleapis.com/translate_a/single"
    params = { client: "gtx", sl: "en", tl: "pt", dt: "t", q: text }
    begin
      response = HTTParty.get(base_url, query: params, timeout: 1.5)
      JSON.parse(response.body)[0].map { |part| part[0] }.join
    rescue; text; end
  end
end