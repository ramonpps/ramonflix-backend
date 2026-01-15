class StreamsController < ApplicationController
  require 'httparty'
  require 'uri'

  def index
    puts "\n=== BUSCA METADADOS + TRADUÇÃO + MAGNETS ==="
    imdb_id = params[:imdb_id]
    type = params[:type]
    title_hint = params[:title_hint]
    
    # === 1. BUSCA METADADOS ===
    meta_data = {}
    
    begin
      url_meta = "https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json"
      meta_response = HTTParty.get(url_meta, timeout: 5)
      
      if meta_response.success?
        data = JSON.parse(meta_response.body)['meta']
        original_title = data['name']
        original_desc = data['description']
        
        # === TRADUÇÃO (GOOGLE GTX) ===
        translated_title = original_title
        translated_desc = original_desc

        if original_title.present?
           translated_title = translate_google(original_title)
        end

        if original_desc.present?
          translated_desc = translate_google(original_desc) 
        end

        meta_data = {
          name: translated_title,         
          original_name: original_title,  
          description: translated_desc,   
          imdbRating: data['imdbRating'],
          cast: data['cast'] || [],       
          poster: data['poster'],
          background: data['background'],
          year: data['releaseInfo']
        }
      end
    rescue => e
      puts "⚠️ Erro Metadata: #{e.message}"
    end

    # === 2. LINKS DO TORRENTIO ===
    stream_id = (type == 'series') ? "#{imdb_id}:#{params[:season]}:#{params[:episode]}" : imdb_id
    
    br_providers = "comando,bludv,lapumia,wayup,nezu,ondebaixa"
    url_br = "https://torrentio.strem.fun/providers=#{br_providers}%7Clanguage=portuguese/stream/#{type}/#{stream_id}.json"
    url_global = "https://torrentio.strem.fun/sort=seeders%7Cqualityfilter=4k/stream/#{type}/#{stream_id}.json"

    streams_br = []
    streams_global = []

    threads = []
    threads << Thread.new { streams_br = JSON.parse(HTTParty.get(url_br, timeout: 15).body)['streams'] rescue [] }
    threads << Thread.new { streams_global = JSON.parse(HTTParty.get(url_global, timeout: 15).body)['streams'] rescue [] }
    threads.each(&:join)

    # Processamento e Scores
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

    # Remove duplicatas BR da lista global
    br_regex = /dublado|dual|nacional|pt-br|portugues/i
    raw_subtitled = raw_subtitled.reject { |s| s['title'].match?(br_regex) }

    # === A CORREÇÃO ESTÁ AQUI: FORMATAR PARA INCLUIR O MAGNET ===
    dubbed_final = raw_dubbed.map { |s| format_stream(s) }
    subtitled_final = raw_subtitled.map { |s| format_stream(s) }

    render json: {
      meta: meta_data,
      dubbed: dubbed_final,
      subtitled: subtitled_final
    }
  end

  private

  def format_stream(s)
    # Garante que o magnet link seja gerado corretamente
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
      response = HTTParty.get(base_url, query: params, timeout: 2)
      json = JSON.parse(response.body)
      return json[0].map { |part| part[0] }.join
    rescue
      return text
    end
  end
end