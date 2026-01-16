# RamonFlix - Backend API
Link para acesso do sistema em produção: https://ramonflix.vercel.app/
<br>Horários entre as 20h e 8h estão sujeitos a maior latência de tráfego

Este repositório contém a API RESTful do projeto RamonFlix, desenvolvida em **Ruby on Rails**. Esta aplicação atua como o "cérebro" da arquitetura de microsserviços do projeto, sendo responsável pela orquestração de dados, gerenciamento de catálogo e lógica de negócios para a entrega de conteúdo.

O backend foi projetado para operar em **API Only Mode**, servindo dados JSON otimizados para o cliente React e integrando-se com serviços externos de metadados e microsserviços de streaming.

## Sobre o Projeto

O RamonFlix é uma prova de conceito de uma plataforma de streaming. O papel deste backend é agregar informações de APIs públicas de filmes (como Cinemeta e TMDB) e processar as solicitações de reprodução.

Frontend: https://github.com/ramonpps/ramonflix-frontend/ <br>
Backend: https://github.com/ramonpps/ramonflix-backend <br>
Stream service: https://github.com/ramonpps/ramonflix-stream-service <br>

> **Nota de Implementação:** Para garantir a viabilidade do projeto como portfólio público, este backend implementa uma camada de segurança lógica ("Safe Mode"). Ao receber uma solicitação de streaming para um filme comercial, a API intercepta a requisição e retorna links magnéticos de conteúdo Open Source (Creative Commons), garantindo que a tecnologia P2P possa ser demonstrada sem infração de direitos autorais.

## Tecnologias Utilizadas

* **Framework:** Ruby on Rails 7 (API Mode)
* **Linguagem:** Ruby 3.2
* **Servidor Web:** Puma
* **Comunicação Externa:** HTTParty (para consumo de APIs de metadados)
* **Caching:** Rails Cache (Memory Store/Redis) para otimização de requisições externas
* **Segurança:** Rack CORS para gerenciamento de acesso cross-origin
* **Infraestrutura:** Configurado para deploy contínuo via Render.com

## Principais Funcionalidades

1.  **Agregação de Metadados:** Centraliza e padroniza informações de múltiplas fontes externas (título, ano, poster, sinopse, elenco).
2.  **Gestão de Sessão de Streaming:** Gera os payloads necessários (Magnet Links) para que o microsserviço de transcoding (Node.js) inicie o processamento do vídeo.
3.  **Sistema de Caching:** Implementa cache temporário para reduzir a latência e o número de chamadas às APIs de terceiros.
4.  **Lógica de Fallback:** Sistema inteligente para garantir que sempre haja um conteúdo de vídeo disponível para demonstração, mesmo que os metadados principais falhem.
5.  **Keep-Alive Automation:** Configuração preparada para integração com GitHub Actions, prevenindo o "Cold Start" em ambientes de hospedagem gratuitos.

## Pré-requisitos

* Ruby (versão 3.0 ou superior)
* Bundler
* SQLite3 (para ambiente de desenvolvimento)

## Instalação e Execução

1.  Clone o repositório:
    ```bash
    git clone [https://github.com/SEU_USUARIO/ramonflix-backend.git](https://github.com/SEU_USUARIO/ramonflix-backend.git)
    cd ramonflix-backend
    ```

2.  Instale as dependências (Gems):
    ```bash
    bundle install
    ```

3.  Prepare o banco de dados (necessário para o Rails, mesmo que usemos pouca persistência):
    ```bash
    bin/rails db:prepare
    ```

4.  Inicie o servidor:
    ```bash
    bin/rails s
    ```

A API estará disponível em `http://localhost:3000`.

## Endpoints Principais

* `GET /home`: Retorna coleções de catálogos (Populares, Trending, Sci-Fi) para a página inicial.
* `GET /streams`: Endpoint core que recebe um `imdb_id` e retorna os objetos de streaming (incluindo Magnet Links e legendas simuladas).
* `GET /series`: Gerencia a estrutura de temporadas e episódios para séries de TV.

## Arquitetura do Sistema

Este backend é o componente central do ecossistema:

1.  **Frontend (React):** Consome esta API para exibir a interface.
2.  **Backend API (Este repositório):** Processa dados e lógica.
3.  **Stream Engine (Node.js):** Recebe os Magnet Links gerados por esta API para realizar o streaming de vídeo.

---
Desenvolvido por Ramon Pedro Pereira Santos
