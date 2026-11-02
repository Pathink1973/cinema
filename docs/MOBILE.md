# Cinema no iPhone, iPad e TV

## O que se instala no mobile

A interface mobile já faz parte do projeto. O Mac serve HTML, CSS, JavaScript e a API local. Não precisas de compilar uma segunda app, ter Xcode para iOS, instalar um servidor Node ou publicar na App Store.

O Safari apresenta a biblioteca; o **VLC para iPhone/iPad** reproduz o vídeo. O atalho no ecrã principal não funciona como uma biblioteca offline independente do Mac. Vídeos já descarregados no VLC podem ser vistos offline.

## Configurar

1. Instala o [VLC no iPhone/iPad](https://www.videolan.org/vlc/download-ios.html).
2. Liga o Mac e o dispositivo à mesma rede. Evita redes de convidados que isolem dispositivos.
3. No Mac, abre **Cinema no iPhone → Ativar catálogo na rede Wi-Fi**.
4. Lê o QR code com a câmara do dispositivo e abre a ligação no Safari.
5. Para guardar o ícone, usa **Partilhar → Adicionar ao ecrã principal** no Safari.
6. Abre uma ficha, escolhe a legenda e toca em **Preparar para o VLC**.
7. Aguarda a preparação e verificação até 100%; toca em **Abrir no VLC** ou **Guardar no VLC para ver offline**.

Se o sistema pedir permissão de rede local ao Cinema/VLC, permite-a para esta utilização. A firewall do Mac também tem de permitir a ligação local ao Cinema.

## Legendas e espaço

Coloca os ficheiros juntos, por exemplo:

```text
Filmes/
  O Meu Filme (2024)/
    O Meu Filme (2024).mkv
    O Meu Filme (2024).pt.srt
```

A aplicação cria uma cópia MKV com uma faixa de legendas marcada como predefinida e forçada, sem recodificar vídeo/áudio. Valida a existência da faixa e de eventos antes de disponibilizar o link. Isso não corrige a sincronização nem obriga todas as configurações do VLC a mostrar as legendas: seleciona **Legendas Cinema** se necessário.

A preparação atual exige SRT válido ou uma primeira faixa de legenda interna. Sem legendas, a preparação é bloqueada. A cópia pode ocupar aproximadamente o tamanho do original. Há uma preparação de cada vez e até duas cópias prontas no catálogo; podes libertá-las na ficha ou no painel do Mac.

O Mac deve ficar acordado, com o disco ligado, a aplicação aberta e o catálogo ativo durante o streaming ou download. Fechar apenas o painel do QR não desativa o catálogo. Desativá-lo ou fechar o Cinema termina o acesso e limpa as cópias dessa sessão. Uma saída abrupta pode deixar temporários do sistema.

## Ligação e privacidade

O URL é local e contém um código de acesso aleatório. O catálogo tenta a porta 8787 e escolhe outra se necessário. O URL mantém-se enquanto a porta e o IP do Mac se mantiverem; se deixar de abrir após mudar de rede, volta a ler o QR.

Não publiques o QR/URL. Quem tiver a ligação na rede pode consultar a biblioteca e alterar favoritos e coleções. HTTP local não é encriptado. Não há configuração de acesso público, túnel, contas ou abertura de portas no router. Ver [SECURITY.md](../SECURITY.md).

## Ver na televisão

O caminho já utilizado neste projeto é **Cinema → VLC no iPhone/iPad → Duplicar ecrã para a TV**:

1. Inicia o filme no VLC.
2. Abre a Central de Controlo do iPhone/iPad.
3. Escolhe **Duplicar ecrã** e seleciona o recetor compatível.
4. Volta ao VLC e coloca o filme em ecrã inteiro.
5. Controla play, pausa e volume no VLC.

É necessário um recetor que apareça na lista de duplicação; a capacidade depende da televisão ou equipamento ligado a ela. Selecionar só uma saída de áudio pode deixar o vídeo no dispositivo. Não há um comando LG integrado nem garantia de AirPlay direto para qualquer codec/modelo. Consulta o [guia Apple de AirPlay e duplicação](https://support.apple.com/102661).

## Alterar o visual mobile

Edita `Sources/Cinema/Resources/Web/index.html`, `style.css` e `app.js`; recompila e substitui a app Mac. O cabeçalho, navegação e modais respeitam `safe-area-inset-*` do iOS. Para carregar recursos novos, fecha/reabre o atalho ou atualiza o Safari. Não existe service worker nem cache offline da biblioteca.
