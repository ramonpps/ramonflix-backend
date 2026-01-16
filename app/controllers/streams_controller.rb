class StreamsController < ApplicationController
  require 'httparty'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type] # 'movie' ou 'series'
    title = params[:title_hint]
    
    # Lista final de torrents
    streams = []

    # 1. Se for FILME, busca no YTS (Yify) - É a fonte mais estável
    if type == 'movie'
      yts_streams = fetch_from_yts(imdb_id, title)
      streams.concat(yts_streams)
    end

    # 2. Se o YTS não retornou nada ou se for SÉRIE, tenta o Torrentio
    # (Adicionamos headers para tentar evitar bloqueio)
    if streams.empty? || type == 'series'
      torrentio_streams = fetch_from_torrentio(imdb_id, type, params[:season], params[:episode])
      streams.concat(torrentio_streams)
    end

    render json: streams
  end

  private

  def fetch_from_yts(imdb_id, title)
    begin
      url = "https://yts.mx/api/v2/list_movies.json?query_term=#{imdb_id}"
      response = HTTParty.get(url, timeout: 5)
      
      return [] unless response.code == 200

      data = JSON.parse(response.body)
      return [] unless data['data'] && data['data']['movies']

      movie = data['data']['movies'].first
      return [] unless movie

      # Formata para o padrão que seu frontend espera
      results = movie['torrents'].map do |torrent|
        {
          title: "YTS #{torrent['quality']} - #{torrent['type'].capitalize} (#{torrent['size']})",
          infoHash: torrent['hash'],
          fileIdx: 0, # YTS geralmente é arquivo único
          sources: [
            "dht:#{torrent['hash']}",
            "tr:udp://open.demonii.com:1337/announce",
            "tr:udp://tracker.openbittorrent.com:80",
            "tr:udp://tracker.coppersurfer.tk:6969",
            "tr:udp://glotorrents.pw:6969/announce",
            "tr:udp://tracker.opentrackr.org:1337/announce"
          ]
        }
      end
      
      # Adiciona o título do filme no log para debug
      puts "⚡ [YTS] Encontrados #{results.length} torrents para #{title}"
      return results

    rescue StandardError => e
      puts "❌ [YTS Error] #{e.message}"
      return []
    end
  end

  def fetch_from_torrentio(imdb_id, type, season, episode)
    begin
      # Constrói a URL do Torrentio
      identifier = type == 'series' ? "#{imdb_id}:#{season}:#{episode}" : imdb_id
      url = "https://torrentio.strem.fun/stream/#{type}/#{identifier}.json"

      # Cabeçalhos para fingir ser um navegador (Evita bloqueio do Render)
      headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.5"
      }

      response = HTTParty.get(url, headers: headers, timeout: 8)
      
      return [] unless response.code == 200
      
      data = JSON.parse(response.body)
      return [] unless data['streams']

      # Mapeia o retorno do Torrentio
      results = data['streams'].map do |stream|
        {
          title: stream['title'].split("\n").first, # Limpa o título
          infoHash: stream['infoHash'],
          fileIdx: stream['fileIdx'] || 0,
          sources: [
            "dht:#{stream['infoHash']}"
          ]
        }
      end

      puts "⚡ [TORRENTIO] Encontrados #{results.length} torrents."
      return results

    rescue StandardError => e
      puts "❌ [Torrentio Error] #{e.message}"
      return []
    end
  end
end