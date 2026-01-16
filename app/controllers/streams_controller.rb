class StreamsController < ApplicationController
  require 'httparty'
  require 'uri'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type]
    season = params[:season]
    episode = params[:episode]
    title_hint = params[:title_hint]

    # Cache de 12 horas para ser extremamente rápido nas próximas chamadas
    cache_key = "stream_portfolio_fast_v1/#{imdb_id}/#{type}/#{season}/#{episode}"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      fetch_data_safe_mode(imdb_id, type, season, episode, title_hint)
    end

    render json: json_result
  end

  private

  def fetch_data_safe_mode(imdb_id, type, season, episode, title_hint)
    meta_data = {}

    # 1. BUSCA METADADOS REAIS (Cinemeta API)
    # Sem tradução: repassa exatamente o que vier da API (Inglês) para velocidade máxima.
    begin
      url_meta = "https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json"
      meta_response = HTTParty.get(url_meta, timeout: 4) # Timeout curto para não travar
      
      if meta_response.success?
        data = JSON.parse(meta_response.body)['meta']
        
        ep_title = nil
        ep_desc = nil
        
        # Se for série, busca dados do episódio específico no array
        if type == 'series' && season.present?
           # Encontra o episódio na lista gigante de vídeos que o Cinemeta retorna
           target = data['videos']&.find { |v| v['season'].to_s == season.to_s && v['episode'].to_s == episode.to_s }
           if target
              ep_title = target['name'] || "Episode #{episode}"
              ep_desc = target['overview'] || target['description']
           end
        end

        meta_data = {
          name: data['name'],          # Original (Inglês)
          description: data['description'], # Original (Inglês)
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
    rescue => e
      # Fallback em caso de erro na API de metadados
      puts "Erro Meta: #{e.message}"
      meta_data = { name: URI.decode_www_form_component(title_hint || "Unknown Title") }
    end

    # 2. GERAÇÃO DE STREAMS "SAFE" (Demo Mode)
    # Mantém a lógica de portfólio seguro, retornando Sintel/Big Buck Bunny
    
    label_suffix = type == 'series' ? "S#{season}E#{episode}" : "Full Movie"
    
    safe_streams = [
      {
        title: "⚡ High Speed Stream (Demo: Sintel 4K)",
        name: "Primary Server",
        infoHash: "08ada5a7a6183aae1e09d831df6748d566095a10", # Sintel
        score: 10000
      },
      {
        title: "⚡ Backup Stream (Demo: Big Buck Bunny)",
        name: "Backup Server",
        infoHash: "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c", # Big Buck Bunny
        score: 5000
      }
    ]

    # Mapeia para Dublado/Legendado (apenas para manter a UI povoada, o conteúdo é o mesmo)
    dubbed_final = safe_streams.map { |s| format_stream(s, "DUB - #{label_suffix}") }
    subtitled_final = safe_streams.map { |s| format_stream(s, "SUB - #{label_suffix}") }

    {
      meta: meta_data,
      dubbed: dubbed_final,
      subtitled: subtitled_final
    }
  end

  def format_stream(s, prefix)
    # Gera o Magnet Link Seguro
    magnet_link = "magnet:?xt=urn:btih:#{s[:infoHash]}&dn=DemoContent&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337"
    {
      magnet: magnet_link,
      title: "#{prefix} | #{s[:title]}",
      name: s[:name],
      infoHash: s[:infoHash],
      score: s[:score]
    }
  end
end