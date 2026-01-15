class StreamsController < ApplicationController
  require 'httparty'

  def index
    puts "\n=== NOVA BUSCA (MODO CONFIANÇA BR) ==="
    imdb_id = params[:imdb_id]
    type = params[:type]
    season = params[:season]
    episode = params[:episode]
    
    stream_id = (type == 'series') ? "#{imdb_id}:#{season}:#{episode}" : imdb_id
    
    # Busca Nome Oficial (apenas para referência)
    real_title = ""
    begin
      meta = HTTParty.get("https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json", timeout: 5)
      real_title = JSON.parse(meta.body).dig('meta', 'name') if meta.success?
    rescue; end

    # === URLS ===
    # BR: Filtra especificamente por provedores confiáveis e tag Portuguese
    config_br = "providers=comando,bludv,micoleaodublado,lapumia%7Clanguage=portuguese"
    url_br = "https://torrentio.strem.fun/#{config_br}/stream/#{type}/#{stream_id}.json"

    # Global: Filtra 4k e prioriza seeders
    config_global = "sort=seeders%7Cqualityfilter=4k"
    url_global = "https://torrentio.strem.fun/#{config_global}/stream/#{type}/#{stream_id}.json"

    streams_br = []
    streams_global = []

    # === THREADS ===
    threads = []
    
    threads << Thread.new do
      begin
        res = HTTParty.get(url_br, timeout: 15)
        streams_br = JSON.parse(res.body)['streams'] || [] if res.success?
      rescue; end
    end

    threads << Thread.new do
      begin
        res = HTTParty.get(url_global, timeout: 15)
        streams_global = JSON.parse(res.body)['streams'] || [] if res.success?
      rescue; end
    end

    threads.each(&:join)

    # === PROCESSAMENTO ===
    
    normalize = ->(str) { str.to_s.downcase.gsub(/[^a-z0-9]/, '') }
    stop_words = ['the', 'and', 'of', 'to', 'in', 'at']

    process_streams = lambda do |list, source_type|
      list.map do |stream|
        score = 0
        torrent_title = stream['title'].to_s
        
        # === A GRANDE MUDANÇA ===
        pass_sanity = false
        
        if source_type == :br
           # MODO CONFIANÇA: Se veio da URL BR (que já tem filtro language=portuguese),
           # nós ACEITAMOS TUDO. Isso permite arquivos nomeados em Inglês ("Pirates... DUAL")
           # aparecerem na lista de Dublados.
           pass_sanity = true
           score += 20000 
        else 
           # Fonte Global: Aqui precisamos filtrar lixo
           if real_title.present?
             real_norm = normalize.call(real_title)
             stream_norm = normalize.call(torrent_title)
             
             # Verifica se tem palavras chaves do título em inglês
             keywords = real_norm.split(stop_words.join('|')).reject(&:empty?)
             match_count = keywords.count { |k| stream_norm.include?(k) }
             
             if keywords.any? && (match_count.to_f / keywords.length > 0.4)
               pass_sanity = true
               score += 5000
             end
           end
        end

        score = -999999 unless pass_sanity

        # === CHECK DE SÉRIES ===
        if type == 'series' && pass_sanity
           full_text = "#{stream['title']} #{stream['name']}".downcase
           s_tag = "s#{season.to_s.rjust(2, '0')}"
           e_tag = "e#{episode.to_s.rjust(2, '0')}"
           unless full_text.include?(s_tag) && full_text.include?(e_tag) || full_text.match?(/#{season}x0?#{episode}/)
              score = -999999 
           end
        end

        # === QUALIDADE ===
        if score > 0
          score += 1000 if torrent_title.match?(/x264|h264|avc/i)
          score -= 2000 if torrent_title.match?(/x265|hevc/i) 
          score += 500 if torrent_title.include?('1080')
          score -= 500 if torrent_title.match?(/4k|2160p/i) 
        end

        stream.merge('compatibility_score' => score)
      end
    end

    # === SEPARAÇÃO ===
    
    processed_br = process_streams.call(streams_br, :br)
    dubbed_final = processed_br.select { |s| s['compatibility_score'] > 0 }
                               .sort_by { |s| -s['compatibility_score'] }

    processed_global = process_streams.call(streams_global, :global)
    
    # Remove da lista global qualquer coisa que pareça BR para não duplicar
    br_identifiers = /dublado|dual|nacional|pt-br|portugues/i
    subtitled_final = processed_global.select { |s| s['compatibility_score'] > 0 && !s['title'].match?(br_identifiers) }
                                      .sort_by { |s| -s['compatibility_score'] }

    puts "✅ Final: #{dubbed_final.count} Dublados | #{subtitled_final.count} Legendados"

    render json: {
      dubbed: dubbed_final.map { |s| format_stream(s) },
      subtitled: subtitled_final.map { |s| format_stream(s) },
      subtitles: []
    }
  end

  private
  def format_stream(s)
    {
      magnet: "magnet:?xt=urn:btih:#{s['infoHash']}",
      title: s['title'] || "Sem Título",
      name: s['name'] || "Torrent",
      infoHash: s['infoHash'],
      score: s['compatibility_score']
    }
  end
end