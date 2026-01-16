class StreamsController < ApplicationController
  require 'httparty'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type]
    title = params[:title_hint]
    
    streams = []

    # 1. Tenta buscar no The Pirate Bay (APIBay) pelo código IMDB (Mais preciso)
    # Funciona bem para filmes populares
    puts "🔍 [TPB] Buscando por IMDB: #{imdb_id}"
    tpb_streams = fetch_from_apibay(imdb_id)
    streams.concat(tpb_streams)

    # 2. Se não achou nada pelo código, busca pelo TÍTULO (Fallback)
    if streams.empty? && title.present?
      puts "🔍 [TPB] Buscando por Título: #{title}"
      tpb_title_streams = fetch_from_apibay(title)
      # Filtra resultados para garantir que não venha lixo
      streams.concat(tpb_title_streams.take(5)) 
    end

    # 3. Backup: Torrentio (Se ainda estiver vazio)
    if streams.empty?
      puts "🔍 [Torrentio] Tentando backup..."
      torrentio_streams = fetch_from_torrentio(imdb_id, type, params[:season], params[:episode])
      streams.concat(torrentio_streams)
    end

    # Remove duplicatas baseadas no Hash
    streams.uniq! { |s| s[:infoHash] }

    puts "✅ [FINAL] Retornando #{streams.length} opções."
    render json: streams
  end

  private

  def fetch_from_apibay(query)
    begin
      # APIBay não bloqueia servidores facilmente
      url = "https://apibay.org/q.php?q=#{URI.encode_www_form_component(query)}"
      
      response = HTTParty.get(url, timeout: 10)
      
      if response.code != 200
        puts "❌ [TPB Error] Status Code: #{response.code}"
        return [] 
      end

      data = JSON.parse(response.body)

      # APIBay retorna [{name: 'No results returned', ...}] quando não acha nada
      return [] if data.is_a?(Array) && data.first && data.first['name'] == 'No results returned'
      return [] unless data.is_a?(Array)

      # Formata para o padrão do frontend
      results = data.map do |torrent|
        {
          title: "TPB: #{torrent['name']}",
          infoHash: torrent['info_hash'],
          fileIdx: 0,
          sources: [
            "dht:#{torrent['info_hash']}",
            "tr:udp://tracker.coppersurfer.tk:6969/announce",
            "tr:udp://tracker.openbittorrent.com:80/announce",
            "tr:udp://opentrackr.org:1337/announce",
            "tr:udp://9.rarbg.to:2710/announce"
          ]
        }
      end
      
      # Ordena por Seeds (mais seeds = mais rápido) e pega os top 10
      results.sort_by! { |r| -r[:seeders].to_i rescue 0 }.take(10)

      puts "⚡ [TPB] Encontrados #{results.length} torrents para '#{query}'"
      return results

    rescue StandardError => e
      puts "❌ [TPB Exception] #{e.message}"
      return []
    end
  end

  def fetch_from_torrentio(imdb_id, type, season, episode)
    begin
      identifier = type == 'series' ? "#{imdb_id}:#{season}:#{episode}" : imdb_id
      url = "https://torrentio.strem.fun/stream/#{type}/#{identifier}.json"

      # Headers para evitar bloqueio 403/429
      headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
      }

      response = HTTParty.get(url, headers: headers, timeout: 5)
      
      if response.code != 200
        puts "❌ [Torrentio Error] Falha com status: #{response.code}"
        return []
      end
      
      data = JSON.parse(response.body)
      return [] unless data['streams']

      results = data['streams'].map do |stream|
        {
          title: stream['title'].split("\n").first,
          infoHash: stream['infoHash'],
          fileIdx: stream['fileIdx'] || 0,
          sources: ["dht:#{stream['infoHash']}"]
        }
      end

      puts "⚡ [Torrentio] Encontrados #{results.length} torrents."
      return results

    rescue StandardError => e
      puts "❌ [Torrentio Exception] #{e.message}"
      return []
    end
  end
end