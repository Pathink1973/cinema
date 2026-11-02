# Arquitetura

## Tecnologias

- Swift Package, Swift 6, macOS 14+, SwiftUI e AppKit.
- Foundation e JSON para persistência local; Security/LocalAuthentication para acesso não interativo ao Porta-chaves.
- FSEvents para alterações nas pastas, com verificações de segurança e de estabilidade.
- Network.framework para um servidor HTTP local, sem dependências web externas.
- HTML, CSS e JavaScript sem framework para o catálogo mobile.
- Processos FFmpeg/FFprobe externos para preparar e verificar cópias MKV.
- VLC externo para reprodução; TMDB remoto opcional para metadados.

## Mapa do código

Todos os ficheiros Swift abaixo ficam em `Sources/Cinema/`:

| Ficheiro | Responsabilidade |
| --- | --- |
| `App.swift` | Entrada, navegação, ficha e definições |
| `Library.swift` | Estado principal, persistência, ações, TMDB e abertura do VLC |
| `Models.swift` | Filmes, coleções, nomes de ficheiro e correspondências |
| `LibraryScanner.swift`, `FileReadiness.swift` | Enumeração fora da interface e estabilidade de importações |
| `FolderChangeWatcher.swift` | Eventos de alterações nas pastas |
| `HomeView.swift`, `MovieCard.swift`, `CollectionsView.swift` | Apresentação da biblioteca |
| `LibraryToolbar.swift` | Pesquisa e ecrã inteiro nativos |
| `TokenSession.swift` | Cache do token por sessão |
| `PhoneMedia.swift`, `PreparationProgress.swift` | FFmpeg, validação de legendas e progresso |
| `PhoneServer.swift`, `LocalHTTP.swift` | Transporte HTTP e respostas de dados/ficheiro |
| `PhoneShareView.swift` | Partilha individual por QR, com expiração |
| `WebCatalog.swift`, `WebCatalogPanel.swift` | Catálogo mobile, jobs de preparação e painel QR |
| `CinemaResources.swift` | Localização dos recursos no bundle |
| `Resources/Web/` | HTML, CSS, JavaScript e ícones mobile |

`Tests/CinemaTests/` usa Swift Testing, pastas temporárias e pequenos vídeos sintéticos. Os testes de media necessitam de FFmpeg/FFprobe; não usam filmes pessoais nem token TMDB.

## Dados

A biblioteca fica em `~/Library/Application Support/CinemaMac/library.json`. Contém caminhos das pastas e vídeos, metadados, favoritos, vistos, exclusões e coleções. A escrita é atómica. O token TMDB fica no Porta-chaves quando possível, com fallback apenas em memória. Preferências da aplicação guardam a porta e o código aleatório do catálogo local. Nenhum destes dados deve ir para Git.

Preserva a compatibilidade de descodificação de bibliotecas anteriores ao acrescentar propriedades. Alterar nome visível é diferente de mudar bundle ID, serviço Keychain ou pasta de dados; esses últimos exigem estratégia de migração.

## Rede e APIs

O servidor exige um prefixo de URL com código aleatório e aceita clientes locais/privados. Disponibiliza apenas os recursos e rotas definidos, sem navegação arbitrária no disco. Suporta pedidos Range/HEAD para vídeo. As mutações requerem o cabeçalho `X-Cinema-Action: 1` e verificam o Origin quando presente.

Rotas internas sob `/<codigo>/`:

- `GET api/library`: biblioteca e coleções, sem caminhos absolutos dos vídeos.
- `POST api/movies/<id>/favorite`: alterar favorito.
- `POST api/movies/<id>/collection`: associar/retirar de uma coleção.
- `POST api/collections`: criar coleção.
- `POST api/movies/<id>/prepare`: iniciar preparação com índice de legenda ou faixa interna.
- `GET api/jobs/<id>`: estado e progresso.
- `GET api/jobs/<id>/film.mkv`: vídeo preparado, com Range.
- `POST api/jobs/<id>/remove`: libertar a cópia.

São detalhes de implementação para a interface incluída, sem garantia de API pública estável. Não substituem autenticação multiutilizador ou TLS. O catálogo é um serviço de confiança para rede doméstica; ver [SECURITY.md](../SECURITY.md).

## Build e distribuição

`./scripts/build-app.sh` executa o build release, copia o executável e os bundles de recursos para `dist/Cinema.app`, gera Info.plist e aplica assinatura ad-hoc. Os recursos mobile têm de estar no bundle final; testar apenas o executável de desenvolvimento não valida o empacotamento.

A app produzida tem a arquitetura da máquina de build. Universal, notarização, atualizações automáticas e distribuição na App Store não estão configurados.
