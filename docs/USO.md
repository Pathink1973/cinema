# Guia de utilização do Cinema

Aplicação SwiftUI local inspirada na navegação de uma sala de cinema. Requer macOS 14+, VLC instalado e, para compilar, Swift 6/Xcode.

## Catálogo web para iPhone

Na barra lateral da app do Mac, abre **Cinema no iPhone → Ativar catálogo na rede Wi-Fi**. Lê o QR code com a câmara do iPhone e abre no Safari. A página apresenta o visual escuro/âmbar, o ícone Cinema, destaque, filas de capas, biblioteca, pesquisa por título/realizador/género, favoritos e coleções. Alterar favoritos ou coleções no iPhone guarda a alteração na mesma biblioteca do Mac. Também é possível criar coleções na web e selecionar as coleções na ficha de cada filme.

Abre a ficha, escolhe a legenda e toca em **Preparar para o VLC**. A página acompanha a preparação no Mac com uma barra de 1–100%, fase atual e tempo decorrido. A percentagem usa o tempo de vídeo processado que o FFmpeg reporta, seguido da leitura real dos eventos de legenda pelo FFprobe; só atinge 100% depois de a validação terminar. No Mac, o mesmo progresso aparece no painel do catálogo e no rodapé da janela principal. A partilha individual “Ver no iPhone” também tem a barra. Quando a inclusão e verificação da legenda terminam, aparecem **Abrir no VLC** e **Guardar no VLC para ver offline**. O Safari/iOS pode pedir confirmação para abrir o VLC. A reprodução não é feita no browser. Sem legendas válidas ou se a preparação falhar, não é criada uma ligação ao vídeo.

O Mac deve estar acordado, com o Cinema aberto, o catálogo ativo e o disco dos filmes disponível. Acesso apenas na rede local: não há URL público, túnel nem configuração do router. A aplicação tenta a porta **8787**, procura uma alternativa se estiver ocupada e recorda a porta escolhida nas preferências. O URL contém um código aleatório persistido nas preferências locais (não é o token TMDB). Quem tiver a ligação na mesma rede pode ver a biblioteca e alterar os favoritos/coleções. Desativar o catálogo ou fechar o Cinema termina o acesso. Ao reativar, o URL mantém-se desde que o endereço IP do Mac não tenha mudado.

Podes fechar o painel QR no Mac: o catálogo continua ativo. No Safari do iPhone, usa **Partilhar → Adicionar ao ecrã principal** para guardar o ícone Cinema. É um atalho web para a biblioteca no Mac, sem funcionamento offline; não instala um servidor na cloud. Se o IP mudar, volta a ler o QR code. A navegação funciona sem API TMDB configurada, com as fichas existentes; as capas remotas precisam de internet.

O Mac prepara um filme de cada vez e mantém no máximo duas cópias prontas por sessão para limitar uso de disco. Usa **Libertar cópia temporária** na ficha web de um filme já preparado ou **Limpar cópias temporárias** no painel do Mac para libertar espaço. Fechar a app/desativar o catálogo remove as cópias. Preparar outra legenda cria outra cópia verificada. O ficheiro original nunca é alterado. Downloads concluídos no VLC permanecem no iPhone.

## Ver no iPhone (mesma rede)

Instala o VLC no iPhone. No menu de uma capa ou no menu **…** da ficha, escolhe **Ver no iPhone…**. Seleciona a legenda SRT e clica em **Preparar vídeo com legendas**. Se não houver SRT, é usada a primeira faixa de legenda interna; sem nenhuma legenda, a preparação é bloqueada.

A aplicação cria uma cópia temporária MKV, sem recodificar vídeo/áudio, com a legenda selecionada embutida e marcada como predefinida/forçada. Normaliza SRT para UTF-8. O FFprobe verifica a faixa e conta os eventos de legenda antes de permitir o QR code. Um SRT vazio ou preparação inválida não produz uma ligação. Isso garante a inclusão da faixa; preferências do VLC ainda podem ocultar legendas (ativa **Legendas Cinema** no leitor). O original não é alterado. Não corrige sincronização ou traduções erradas nas legendas de origem.

Lê o QR com a câmara do iPhone e escolhe **Abrir no VLC** ou **Guardar no VLC para ver offline**. A cópia pode ocupar o tamanho do filme e a preparação/verificação pode demorar. São necessários `ffmpeg` e `ffprobe` em `/opt/homebrew/bin` ou `/usr/local/bin` (não incluídos no bundle da app; instala-os antes de usar esta função).

Mantém o Mac acordado, o disco ligado e a janela de partilha aberta. O Mac e o iPhone devem conseguir comunicar na mesma rede; redes de convidados podem bloquear esta comunicação. Se o macOS pedir autorização de rede local ou a firewall bloquear ligações recebidas, autoriza o Cinema. O endereço pode ser escolhido no modal quando há várias interfaces.

O servidor só disponibiliza a cópia desse filme, com token aleatório no endereço, aceita pedidos de endereços privados/locais e suporta HTTP Range/HEAD para avanço e download. Não publica um URL na internet nem configura portas do router. Qualquer pessoa na rede que tenha o link pode aceder ao filme enquanto a partilha está ativa. A ligação termina ao fechar o modal ou após 2 horas; a cópia temporária é removida. Downloads concluídos no iPhone continuam disponíveis depois disso. Saídas abruptas da app podem deixar ficheiros temporários do sistema. A compatibilidade dos codecs e a ativação de legendas no leitor dependem da versão do VLC; testa sempre o teu dispositivo e os teus ficheiros antes de uma sessão.

## Coleções

Na barra lateral, abre **Coleções** e cria uma coleção, por exemplo **Wes Anderson**. Usa **Selecionar filmes** para marcar vários títulos; a pesquisa aceita título e realizador (quando a ficha TMDB o inclui). Guarda para aplicar a seleção. Também podes usar **Adicionar à coleção…** no menu de contexto de qualquer capa ou no menu **…** da ficha. O seletor permite criar uma coleção e adicionar o filme diretamente. Um filme pode pertencer a várias coleções. **Retirar da coleção** mantém o filme na biblioteca. Apagar uma coleção requer confirmação e preserva filmes e ficheiros. Coleções são guardadas localmente com a biblioteca e preservam associações de vídeos temporariamente excluídos.

## Ações nas capas e ficha em modal

Cada capa inclui um botão **Ver** (abre no VLC com a primeira legenda externa disponível) e um coração para adicionar ou retirar dos favoritos. Clicar na imagem ou no título abre uma ficha em modal com fundo cinematográfico, sinopse completa, metadados e seleção de legendas. A ficha fecha com **Esc** ou no botão **×**. As opções de identificar, atualizar dados e excluir continuam disponíveis.

## Pesquisa e controlos

A pesquisa fica fixa no topo e aceita títulos apresentados/originais, realizador, género, ano e nome do ficheiro, com tolerância a acentos e espaços. Mostra os resultados de toda a biblioteca diretamente na grelha, sem o destaque a ocupar o ecrã. Usa **⌘F** para focar a pesquisa e **Esc** para limpar; **Enter** não inicia um filme durante a escrita. O botão de ecrã inteiro atua na janela onde está colocado. A atualização de disco é independente da obtenção de metadados TMDB e um pedido durante outra verificação fica em fila.

## Início

A aplicação abre no **Início**, com um destaque e filas horizontais de capas grandes. O destaque inicial escolhe o filme com data de importação mais recente, tanto no Mac como na web; selecionar uma capa no Mac permite mudar manualmente o destaque. Filmes antigos sem data de importação ficam atrás dos novos. Selecionar uma capa atualiza a ficha em destaque; as setas nas filas e as teclas esquerda/direita (com a fila focada) permitem navegar. O trackpad permite deslocar cada fila horizontalmente. Só entram nas filas filmes com capa TMDB. A Biblioteca mantém a grelha completa e pesquisar no Início mostra também resultados sem capa.

Novos vídeos passam a guardar a data de importação para a fila **Adicionados recentemente**. Para bibliotecas anteriores sem datas, a primeira fila apresenta **Da tua coleção**, sem inventar uma ordem cronológica.

## Abrir

Depois de [compilar e instalar](INSTALACAO.md), abre o Cinema. O bundle tem assinatura ad-hoc; não tem assinatura Developer ID nem notarização da Apple.

1. Clica em **Adicionar pasta** e escolhe uma ou mais pastas de filmes. Inclui subpastas. Discos externos e partilhas de rede devem estar montados no Finder.
2. Seleciona um filme e escolhe **Ver no VLC**. O VLC abre em ecrã inteiro.
3. Nas **Definições**, adiciona o **API Read Access Token** da tua conta em https://www.themoviedb.org/settings/api. Usa o token de leitura, não a API key v3. O token é guardado no Porta-chaves e lido apenas uma vez por sessão; os pedidos seguintes reutilizam a cópia em memória. Guardar outro token atualiza essa cópia. Se recusares acesso, volta a guardar o token nas definições ou reabre a aplicação para tentar novamente. As consultas ao Porta-chaves não permitem janelas de autenticação. Se o macOS bloquear o acesso (por exemplo, após uma atualização assinada localmente), cola novamente o token nas Definições. Guardar ativa o token em memória mesmo se o Porta-chaves não permitir a escrita; nesse caso, será necessário voltar a colá-lo noutra sessão. A palavra-passe do Mac nunca é guardada pela aplicação.
4. Clica em **Procurar capas no TMDB**. A pesquisa automática compara o título traduzido e original, normaliza pontuação e acentos, tolera pequenas gralhas e diferenças de um ano na estreia. Se necessário, repete a pesquisa sem filtro de ano e compara os candidatos. Resultados demasiado próximos ficam para confirmação; usa **Identificar…** para escolher outro resultado ou procurar pelo título original.

A biblioteca inclui pesquisa local, favoritos, marcação de vistos, histórico de filmes abertos, capas, fundos, sinopses, ano, duração, classificação TMDB, géneros, realização e elenco. Sem token, a biblioteca e a reprodução local continuam disponíveis. As imagens são carregadas da internet; os metadados ficam guardados localmente.

## Procurar dados em falta

No menu de contexto de uma capa, ou no menu **…** da ficha, escolhe **Procurar dados em falta**. Se o filme já tem um ID TMDB, atualiza essa ficha. Caso contrário, tenta identificá-lo pelo nome e ano; quando há ambiguidade, apresenta os candidatos e uma pesquisa editável. Campos existentes são preservados quando o TMDB devolve um campo vazio para o mesmo filme. Ao corrigir para outro filme, os dados anteriores não são misturados. Capas e campos ausentes no próprio TMDB podem continuar em falta.

## Remover vídeos da biblioteca

Clica com o botão direito numa capa e escolhe **Remover da biblioteca**, ou usa o menu **…** na ficha. O vídeo desaparece da biblioteca sem alterar o ficheiro nem as legendas. A exclusão é guardada por caminho e mantém-se ao atualizar as pastas e reabrir a aplicação. Se moveres ou renomeares o ficheiro, o novo caminho pode ser importado como outro vídeo.

Em **Definições → Vídeos excluídos**, clica em **Restaurar** para o voltar a mostrar, preservando capa, favoritos e histórico.

## Legendas

Coloca as legendas na mesma pasta do vídeo, com o mesmo nome base:

```
Arrival (2016).mkv
Arrival (2016).pt.srt
Arrival (2016).en.srt
```

São aceites `.srt` com nome base idêntico ou seguido de um ponto e idioma. Seleciona a legenda no menu antes de reproduzir. O VLC também gere faixas internas e as suas preferências de deteção automática. “Sem ficheiro externo” significa que a aplicação não envia uma legenda externa; as preferências do VLC podem continuar a detetar legendas.

## Armazenamento e limites desta versão

A biblioteca usa JSON com escrita atómica em `~/Library/Application Support/CinemaMac/library.json`. Para esta primeira versão, evita uma dependência SQLite; pode ser migrada depois. Os filmes e legendas originais nunca são movidos ou alterados.

**Recentes** regista os filmes abertos, não o progresso. A retoma depende das definições do VLC. “Visto” é uma marcação manual. A reprodução decorre no VLC, não dentro da janela da aplicação.

Com o Cinema aberto, alterações nas pastas e subpastas disparam uma verificação por eventos do sistema, com agrupamento de alterações rápidas. A ligação de discos também dispara uma atualização. A cada 15 segundos só são revistos ficheiros ainda a estabilizar; há uma verificação de segurança a cada 2 minutos para partilhas ou volumes que não emitam eventos. A enumeração e leitura de metadados ficam fora da interface, usando informação obtida em conjunto pelo sistema de ficheiros e agrupando legendas por pasta. A aplicação não monitoriza pastas enquanto está fechada. Também podes atualizar com ⌘R ou arrastar pastas para a janela. Novos vídeos não vazios entram após duas observações com tamanho, data de modificação e legendas estáveis por pelo menos 10 segundos. Esta é uma verificação heurística: uma cópia pausada durante muito tempo pode parecer concluída. As legendas adicionadas depois são associadas na próxima verificação. Novidades são agrupadas num aviso discreto com acesso à ficha, guardam data de importação e recebem uma tentativa de identificação automática se o token TMDB estiver disponível. Sem token, a importação local continua normalmente. Entradas antigas são preservadas quando um disco fica desligado ou um ficheiro deixa de estar presente. Remove a pasta nas definições para retirar as suas entradas da biblioteca. Isso não elimina ficheiros do disco.

A escolha automática de metadados pode precisar de correção. Remakes sem ano, sequelas diferentes e resultados com baixa confiança não são associados automaticamente. Os formatos reconhecidos são MKV, MP4, AVI, MOV, M4V e WebM; o suporte dos codecs depende do VLC. A ficha e classificação são do TMDB, não do IMDb. Há um servidor HTTP local para o catálogo mobile e streaming para VLC. Não há contas de utilizador, acesso público pela internet, gestão de séries por episódios ou comando remoto da TV.

## Desenvolvimento

```sh
swift build
swift test
./scripts/build-app.sh
```

O último comando gera `dist/Cinema.app`, incluindo os recursos do Swift Package. Abre a pasta como projeto Swift Package no Xcode para desenvolver.

## Referências e atribuição

Referências visuais (sem reutilização de código):
- https://github.com/Fardin7798/apple-tv-launcher
- https://github.com/petrobot-admin/hume-launcher

Dados e imagens: TMDB. O logótipo oficial está incluído nas definições.
This product uses the TMDB API but is not endorsed or certified by TMDB.

VLC: https://www.videolan.org/vlc/ (aplicação externa, não incluída).
