# Contribuir

São bem-vindas melhorias de interface, acessibilidade, compatibilidade, documentação e testes. Este é um projeto comunitário experimental, sem garantia de suporte ou prazos.

1. Faz um fork e clona-o.
2. Cria uma branch com um nome descritivo.
3. Lê `AGENTS.md` e o mapa em `docs/ARQUITETURA.md`.
4. Faz uma mudança de âmbito claro e atualiza os guias afetados.
5. Executa `./scripts/check-environment.sh`, `swift test` e `./scripts/build-app.sh` no Mac.
6. Revê o diff e abre um pull request com o problema resolvido, resultado e validação. Indica o que não testaste fisicamente.

Para lógica de biblioteca, usa dados sintéticos e pastas temporárias. Para legendas, usa pequenos vídeos gerados por FFmpeg; não adiciones filmes ou legendas de terceiros. Mudanças apenas de texto/CSS não precisam de testes que repliquem a implementação, mas exigem revisão visual adequada.

Não publiques tokens TMDB/OpenAI, passwords, certificados, dados de biblioteca, URLs com códigos de acesso ou capturas privadas. Não mudes o armazenamento sem pensar na migração. Mantém o uso local e não destrutivo dos ficheiros originais.

Não acrescentes uma dependência nem um serviço cloud sem justificar a necessidade. O mobile deve continuar a funcionar com o servidor local incluído. O controlo do VLC desktop e a integração com o VLC iOS têm capacidades diferentes.

Ao contribuir, disponibilizas o código original da contribuição sob a licença MIT do projeto. Identifica qualquer material de terceiros e a sua licença. Mantém a discussão respeitosa e concreta.
