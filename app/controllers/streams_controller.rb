class StreamsController < ApplicationController
  require 'httparty'

  def index
    imdb_id = params[:imdb_id]
    type = params[:type]
    season = params[:season]
    episode = params[:episode]
    title_hint = params[:title_hint]

    # Cache na Memória RAM (Rápido e sem custo)
    cache_key = "stream_v10_sqlite/#{imdb_id}/#{type}/#{season}/#{episode}"

    json_result = Rails.cache.fetch(cache_key, expires_in: 12.hours) do
      fetch_data_parallel(imdb_id, type, season, episode, title_hint)
    end

    render json: json_result
  end

  private

  def fetch_data_parallel(imdb_id, type, season, episode, title_hint)
    meta_data = {}
    streams_raw = []

    # Thread 1: Metadados
    t_meta = Thread.new do
      begin
        url_meta = "https://v3-cinemeta.strem.io/meta/#{type}/#{imdb_id}.json"
        res = HTTParty.get(url_meta, timeout: 6)
        if res.success?
          data = JSON.parse(res.body)['meta']
          
          trans_title = translate_google(data['name']) 
          trans_desc = translate_google(data['description'])
          ep_title, ep_desc = nil, nil
          
          if type == 'series' && season.present? && episode.present?
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
      rescue; end
    end

    # Threads de Busca (Unificadas)
    stream_id = (type == 'series') ? "#{imdb_id}:#{season}:#{episode}" : imdb_id
    
    # Busca BR
    t_br = Thread.new do
      begin
        url = "https://torrentio.strem.fun/providers=comando,bludv,lapumia,wayup,nezu,ondebaixa%7Clanguage=portuguese/stream/#{type}/#{stream_id}.json"
        res = HTTParty.get(url, timeout: 10) 
        if res.success?
           list = JSON.parse(res.body)['streams'] || []
           list.each { |s| s['_origin'] = :br }
           streams_raw.concat(list)
        end
      rescue; end
    end

    # Busca Global
    t_global = Thread.new do
      begin
        url = "https://torrentio.strem.fun/sort=seeders%7Cqualityfilter=4k/stream/#{type}/#{stream_id}.json"
        res = HTTParty.get(url, timeout: 10)
        if res.success?
           list = JSON.parse(res.body)['streams'] || []
           list.each { |s| s['_origin'] = :global }
           streams_raw.concat(list)
        end
      rescue; end
    end

    [t_meta, t_br, t_global].each(&:join)

    # === PROCESSAMENTO UNIFICADO ===
    dubbed_list = []
    subtitled_list = []
    
    dubbed_regex = /dublado|dual|nacional|pt-br|portugues/i

    streams_raw.each do |stream|
      title = stream['title'].to_s.downcase
      score = 0
      valid = false

      if type == 'series'
        s_int = season.to_i; e_int = episode.to_i
        
        # Regex Específico (S01E01)
        strict_regex = /(s0?#{s_int}[\s\.]*e0?#{e_int}(?![0-9]))|(\b#{s_int}x0?#{e_int}(?![0-9]))/i
        # Regex Pack (S01 não seguido de E05)
        pack_regex = /\b(s0?#{s_int}|season\W*0?#{s_int})\b(?![.\s-]*e\d+)/i

        if title.match?(strict_regex)
           valid = true; score = 10000
        elsif title.match?(pack_regex)
           valid = true; score = 8000
           score += 500 if title.include?("complete") || title.include?("season")
        else
           score = -999999
        end
      else
        valid = true; score = 10000
        if stream['_origin'] == :global && meta_data[:original_name]
           score += 5000 if title.include?(meta_data[:original_name].downcase.split(' ').first)
        end
      end

      if score > 0
         score += 2000 if title.include?('4k'); score += 1000 if title.include?('1080p')
         
         final_obj = format_stream(stream).merge('score' => score)
         
         if title.match?(dubbed_regex) || stream['_origin'] == :br
            dubbed_list << final_obj
         else
            subtitled_list << final_obj
         end
      end
    end

    dubbed_list.sort_by! { |s| -s['score'] }
    subtitled_list.sort_by! { |s| -s['score'] }
    dubbed_list.uniq! { |s| s[:infoHash] }
    subtitled_list.uniq! { |s| s[:infoHash] }

    {
      meta: meta_data || { name: title_hint },
      dubbed: dubbed_list,
      subtitled: subtitled_list
    }
  end

  def format_stream(s)
    magnet_link = s['magnet'] || "magnet:?xt=urn:btih:#{s['infoHash']}"
    {
      magnet: magnet_link,
      title: s['title'] || "Sem Título",
      name: s['name'] || "Torrent",
      infoHash: s['infoHash']
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