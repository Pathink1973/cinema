# Cinema: instruções para agentes de programação

## Projeto

Aplicação nativa macOS 14+ em Swift 6/SwiftUI/AppKit, com catálogo web mobile servido na LAN pelo mesmo executável. Ler README.md e docs/ARQUITETURA.md antes de alterações estruturais. Interface e documentação em português europeu.

## Comandos

- `./scripts/check-environment.sh`: diagnóstico, sem instalar ferramentas.
- `swift build`: compilação de desenvolvimento.
- `swift test`: testes Swift Testing; FFmpeg/FFprobe necessários para media.
- `./scripts/build-app.sh`: bundle release em dist/Cinema.app, assinatura ad-hoc.

Não é preciso Node/npm nem chave OpenAI. Compilação e testes nativos exigem macOS; se o ambiente não permitir, relata o limite sem afirmar que passaram.

## Contratos que devem ser preservados

- Não modificar, apagar ou mover vídeos e legendas originais. Testes usam temporários e conteúdos sintéticos.
- Preservar compatibilidade de library.json e os dados existentes. Justificar migrações de bundle ID, Keychain ou armazenamento.
- Nunca ler/publicar credenciais do utilizador. Não incluir library.json, tokens, URLs/QR privados, .env ou certificados no Git.
- Token TMDB só nas Definições/Porta-chaves, sem prompts repetidos de autenticação. Não guardar a password do Mac.
- Servidor só para rede local; manter prefixo de acesso, validação de rotas, proteção das mutações e ausência de navegação arbitrária no disco.
- Mobile abre VLC externo; não presumir que APIs de controlo do VLC desktop existem no iOS.
- Preservar validação de legendas e progresso real da preparação; não apresentar 100% antes da verificação.
- Preservar safe areas iOS, acessibilidade e escape de conteúdo no HTML/JavaScript.
- Recursos Web e ícones têm de integrar o bundle final. Verificar o empacotamento ao alterá-los.

## Validação e entrega

Executar verificações proporcionais à mudança. Para lógica Swift, executar swift test; para empacotamento, o build release. Para CSS/HTML, rever layout mobile e desktop. Não afirmar testes físicos de iPhone/TV quando só houve emulação. Atualizar guias para mudanças visíveis.

Não introduzir serviços cloud, bibliotecas pesadas ou publicação automática como efeito lateral de uma alteração local. Não substituir a app instalada nem fazer push se a tarefa não o pedir. Respeitar a licença MIT do código original e os termos separados do TMDB e restantes terceiros.
