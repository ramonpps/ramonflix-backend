class StreamsController < ApplicationController
  # Não precisamos mais de HTTParty para requisições externas arriscadas

  def index
    # Recebemos os parâmetros, mas para fins de demonstração técnica,
    # retornaremos conteúdo licenciado Creative Commons de alta qualidade.
    imdb_id = params[:imdb_id]
    title_hint = params[:title_hint] || "Título Desconhecido"
    
    puts "🎥 [Stream Engine] Solicitando mídia para ID: #{imdb_id} (#{title_hint})"

    # Seleciona um conteúdo legal baseado no ID (ou aleatório para variar a demo)
    # Isso simula uma consulta ao banco de dados de ativos da empresa.
    media_asset = select_legal_content(imdb_id)

    # Monta a resposta no formato que o WebTorrent frontend espera
    streams = [
      {
        title: "High Quality Stream: #{media_asset[:name]} (Open Movie Project)",
        infoHash: media_asset[:infoHash],
        fileIdx: 0,
        sources: media_asset[:sources]
      }
    ]

    puts "✅ [Stream Engine] Ativo '#{media_asset[:name]}' preparado para streaming."
    render json: streams
  end

  private

  # Catálogo de filmes Open Source (Creative Commons)
  # Estes filmes são 100% legais para distribuição e streaming.
  def select_legal_content(id)
    catalog = [
      {
        name: "Sintel (4K)",
        infoHash: "08ada5a7a6183aae1e09d831df6748d566095a10",
        sources: [
          "dht:08ada5a7a6183aae1e09d831df6748d566095a10",
          "tr:udp://tracker.leechers-paradise.org:6969",
          "tr:udp://tracker.coppersurfer.tk:6969",
          "tr:udp://tracker.opentrackr.org:1337",
          "tr:udp://explodie.org:6969",
          "tr:udp://9.rarbg.me:2970/announce"
        ]
      },
      {
        name: "Big Buck Bunny",
        infoHash: "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c",
        sources: [
          "dht:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c",
          "tr:udp://tracker.leechers-paradise.org:6969",
          "tr:udp://tracker.coppersurfer.tk:6969"
        ]
      },
      {
        name: "Tears of Steel (Sci-Fi)",
        infoHash: "209c8226b299b308beaf2b9cd3fb49212dbd13ec",
        sources: [
          "dht:209c8226b299b308beaf2b9cd3fb49212dbd13ec",
          "tr:udp://tracker.leechers-paradise.org:6969",
          "tr:udp://tracker.coppersurfer.tk:6969"
        ]
      },
      {
        name: "Cosmos Laundromat",
        infoHash: "c424de29e701981261a867b938f292c2df6a0248",
        sources: [
           "dht:c424de29e701981261a867b938f292c2df6a0248",
           "tr:udp://tracker.leechers-paradise.org:6969"
        ]
      }
    ]

    # Para fins de portfólio, podemos rotacionar o conteúdo
    # ou usar o ID para determinar qual filme tocar (hash simples)
    index = id.hash.abs % catalog.length
    catalog[index]
  end
end