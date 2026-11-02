# Criar a tua versão com o Codex

Este repositório é uma base funcional: o objetivo é adaptar uma aplicação existente, mantendo controlo sobre o que muda. O Codex é opcional e não é uma dependência de execução do Cinema.

## Preparar o projeto

1. Faz um **fork** de [Pathink1973/cinema](https://github.com/Pathink1973/cinema) na tua conta GitHub.
2. Clona o teu fork para o Mac. Para experimentar sem publicar, basta clonar o projeto original.
3. Abre o Codex e associa essa pasta como projeto local/pasta principal.
4. Inicia um chat nessa pasta e pede que leia `AGENTS.md`, `README.md` e os guias relevantes.
5. Usa execução local no Mac para compilar e verificar a aplicação nativa. Um ambiente Linux não consegue compilar SwiftUI/AppKit para macOS.
6. Revê as alterações e os resultados dos testes antes de substituir a aplicação instalada ou publicar.

O `AGENTS.md` contém instruções persistentes do repositório. A pasta principal determina a descoberta destas instruções e as operações Git; consulta a [documentação oficial de projetos](https://learn.chatgpt.com/docs/projects#use-local-projects-for-folders-and-codebases). Os nomes dos controlos podem variar entre versões do Codex.

Não coloques tokens TMDB, palavras-passe ou certificados em prompts. Configura o token na interface do Cinema. Não é necessário adicionar uma API key OpenAI ao código: o Cinema não utiliza a API da OpenAI. O teu acesso ao Codex é separado.

## Primeiro prompt: instalar a base

Copia este pedido para um chat local do Codex na pasta clonada:

```text
Quero criar a minha versão do Cinema a partir deste repositório.
Lê AGENTS.md, README.md e docs/INSTALACAO.md. Verifica o ambiente deste Mac,
identifica dependências em falta e explica o que é necessário instalar.
Quando as ferramentas estiverem disponíveis, executa swift test e
./scripts/build-app.sh. Verifica que dist/Cinema.app inclui o ícone e os
recursos da interface web. Não alteres os meus vídeos ou legendas e não
leias nem publiques credenciais. Explica como instalar o resultado e
ativar a web app no iPhone/iPad. Não publiques alterações no GitHub.
```

Instala as ferramentas em falta a partir das fontes indicadas no guia. O Codex pode precisar de autorizações do sistema para ações concretas; não é necessário desativar proteções do Mac.

## Personalizar o desktop

```text
Lê AGENTS.md e docs/ARQUITETURA.md. Personaliza o Cinema com o nome
"A Minha Sala" e uma paleta azul-escuro/dourado. Mantém as funcionalidades
de biblioteca, VLC, TMDB, favoritos, coleções e mobile. Propõe primeiro
os pontos onde o nome, ícones e cores mudam. Não mudes o formato de
library.json nem os identificadores de armazenamento sem explicar a
migração. Implementa as alterações visuais acordadas, compila e verifica
que os recursos continuam incluídos no bundle.
```

Substitui o nome e as cores pelos teus. Para um ícone novo, fornece uma imagem tua ou pede a criação de um recurso que tenhas direito a distribuir. O build usa `assets/Cinema.icns`; o mobile tem PNG próprios em `Resources/Web`. Alterar apenas um não altera os restantes.

## Personalizar a web app mobile

```text
Quero adaptar o visual mobile do Cinema. Lê AGENTS.md, docs/MOBILE.md e
Sources/Cinema/Resources/Web/. Melhora [descreve a mudança]. Mantém as
APIs existentes, escape seguro de texto, navegação por teclado, contraste,
legendas, progresso e abertura no VLC. Preserva viewport-fit=cover e as
safe areas do iPhone, incluindo modais e navegação inferior. Verifica em
larguras de iPhone e iPad e não afirmes ter testado dispositivos físicos
se só usaste emulação. Recompila o bundle do Mac com os novos recursos.
```

Não peças para publicar esta pasta num alojamento estático: a web app depende da API e dos ficheiros servidos pelo Cinema no Mac. Uma versão pública com contas é outro projeto, com requisitos de autenticação e distribuição de conteúdos diferentes.

## Acrescentar uma funcionalidade

```text
Quero acrescentar [funcionalidade concreta]. Antes de editar, identifica
os modelos, vistas e rotas afetados. Preserva bibliotecas existentes e
ficheiros originais. Implementa a menor alteração completa, acrescenta
testes de comportamento quando apropriado, atualiza os guias e executa
as verificações relevantes. Se alterar o comportamento mobile, verifica
também o bundle e a interface web. Resume o que mudou e o que não foi
possível testar. Não faças push sem eu pedir.
```

Exemplos: uma nova ordenação, filtros por género, melhorias de acessibilidade ou apresentação de coleções. Evita pedidos genéricos como “refaz tudo” quando pretendes uma mudança pequena.

## Reconstruir a ideia de raiz

Para aprender, podes pedir um protótipo separado em vez de editar esta base:

```text
Cria um novo projeto, numa pasta separada, inspirado nas funcionalidades
documentadas deste Cinema. Quero macOS 14+, Swift 6 e SwiftUI, biblioteca
local em JSON, pastas com subpastas, vídeo aberto no VLC e SRT associado.
Começa por essa versão desktop mínima. Depois acrescenta metadados TMDB
com token do próprio utilizador e, só após validar o desktop, um catálogo
web na rede local para iPhone/iPad que abra o VLC. Não copies bases de
dados pessoais ou credenciais. Trabalha por etapas verificáveis e explica
os limites. Não substituas a aplicação ou biblioteca que já tenho.
```

Este prompt descreve uma direção, não garante que outro modelo recrie exatamente a aplicação. Para obter a versão deste repositório, usa o fork e os scripts de build.

## Guardar e partilhar melhorias

Usa uma branch para cada mudança. Revê o diff para remover tokens, caminhos privados, screenshots com QR e ficheiros de biblioteca. Faz commit e push para o teu fork; abre um pull request se quiseres propor a melhoria ao projeto original. Consulta [CONTRIBUTING.md](../CONTRIBUTING.md).
