# Instalar no Mac

## Requisitos

| Componente | Necessário para |
| --- | --- |
| macOS 14+ | Executar a aplicação |
| Swift 6+ e ferramentas de desenvolvimento Apple | Compilar o código |
| Git | Clonar e atualizar o projeto |
| [VLC para Mac](https://www.videolan.org/vlc/download-macosx.html) | Reproduzir localmente |
| [FFmpeg](https://formulae.brew.sh/formula/ffmpeg), incluindo FFprobe | Preparar vídeos e executar os testes de media |
| Conta TMDB e token de leitura | Opcional: procurar capas e fichas |

Apple Silicon e Intel podem compilar a partir do código, desde que tenham uma versão compatível do macOS e do compilador. O script gera apenas a arquitetura do Mac em que é executado; não foi validado em todos os modelos.

## 1. Ferramentas

Instala o Xcode ou as Command Line Tools da Apple. Se não as tiveres, executa:

```sh
xcode-select --install
```

Conclui a instalação e verifica:

```sh
swift --version
git --version
```

A primeira linha tem de indicar Swift 6 ou superior. Se as ferramentas disponíveis tiverem uma versão mais antiga, instala uma versão compatível do Xcode e seleciona-a nas preferências de ferramentas de linha de comandos do Xcode. A versão mínima de execução (macOS 14) não garante que qualquer Xcode antigo consiga compilar o projeto.

Instala o VLC no Mac a partir do site oficial e coloca-o em Aplicações. Para FFmpeg, se já usares [Homebrew](https://brew.sh):

```sh
brew install ffmpeg
```

O Cinema procura `ffmpeg` e `ffprobe` em `/opt/homebrew/bin` (habitual em Apple Silicon) e `/usr/local/bin` (habitual em Intel). Instalações noutro local exigem adaptar `PhoneMedia.tool` em `Sources/Cinema/PhoneMedia.swift`.

## 2. Obter o projeto

```sh
git clone https://github.com/Pathink1973/cinema.git
cd cinema
./scripts/check-environment.sh
```

Em alternativa, faz um fork no GitHub e clona o teu fork. Usa esse endereço nos comandos futuros.

## 3. Testar e criar a aplicação

```sh
swift test
./scripts/build-app.sh
```

O build produz `dist/Cinema.app`, com o executável, os recursos web e o ícone. Não precisas de instalar Node/npm, de alojar um site ou de ter uma conta Apple Developer paga para compilar localmente.

No Finder, abre a pasta `dist` e arrasta **Cinema.app** para **Aplicações**. Abre a aplicação. Para recompilar, fecha primeiro o Cinema, volta a executar o script e substitui a cópia em Aplicações. Não é necessário apagar a biblioteca.

O script usa assinatura **ad-hoc**, não Developer ID nem notarização. Se distribuíres uma cópia compilada, o macOS de outra pessoa pode bloqueá-la. Não desatives o Gatekeeper. Consulta as [instruções oficiais da Apple](https://support.apple.com/102445) e, para distribuição mais ampla, prepara assinatura Developer ID e notarização com as tuas próprias credenciais. Nenhum certificado está incluído.

## 4. Primeira utilização

1. Abre o Cinema e escolhe **Adicionar pasta**.
2. Seleciona a pasta dos teus vídeos. As subpastas são incluídas.
3. Aguarda a deteção e estabilização dos ficheiros. Discos externos devem estar ligados e montados no Finder.
4. Abre um filme com **Ver no VLC**.
5. Opcionalmente, configura o TMDB abaixo.
6. Para mobile, segue [Mobile e TV](MOBILE.md).

## 5. TMDB, sem partilhar credenciais

1. Cria ou usa a tua conta no [TMDB](https://www.themoviedb.org).
2. Consulta a [introdução oficial à API](https://developer.themoviedb.org/docs/getting-started) e solicita acesso de desenvolvimento nas definições da conta, pelo computador.
3. Usa um nome e uma descrição reais da tua aplicação pessoal. Se o formulário exigir URL, usa o endereço real do teu fork ou deste projeto e explica que é uma app desktop pessoal.
4. Copia o **API Read Access Token**, não a chave API v3.
5. Em **Cinema → Definições**, cola o token no campo próprio e guarda.
6. Usa **Procurar capas no TMDB**. Se o resultado for ambíguo, abre **Identificar…** na ficha.

Não precisas de Apidog para configurar o Cinema. Não coloques o token no código, num commit, num issue ou num prompt. O Cinema tenta guardá-lo no Porta-chaves e reutiliza-o em memória. Se a gravação estiver bloqueada, fica disponível só nessa sessão; volta a colar nas definições na sessão seguinte. Nunca guardes a palavra-passe do Mac no Cinema.

Cada utilizador usa a sua própria conta e respeita os [termos de utilização da API](https://developer.themoviedb.org/docs/faq).

## Atualizar a partir do repositório

Se não modificaste o código:

```sh
git pull --ff-only
swift test
./scripts/build-app.sh
```

Se personalizaste a aplicação, guarda as alterações num commit no teu fork e integra as atualizações com revisão dos conflitos. Não uses comandos que apaguem alterações locais para atualizar.
