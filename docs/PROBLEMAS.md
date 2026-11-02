# Problemas frequentes

| Sintoma | O que verificar |
| --- | --- |
| Swift não compila | `swift --version` deve indicar 6+; confirma ferramentas Apple selecionadas e macOS compatível. |
| FFmpeg não encontrado | Instala `brew install ffmpeg`; o Cinema procura em `/opt/homebrew/bin` e `/usr/local/bin`. |
| VLC não abre no Mac | Instala o VLC oficial em Aplicações e confirma que o vídeo ainda existe no disco. |
| Os novos filmes demoram a surgir | A importação espera tamanho/data/legendas estáveis durante pelo menos 10 s e duas observações; aguarda ou usa ⌘R. |
| Disco desligado | Monta-o no Finder. A biblioteca preserva entradas indisponíveis; isso não significa que o vídeo esteja acessível. |
| Capas erradas ou em falta | Confirma o token TMDB e usa **Identificar…** ou **Procurar dados em falta**. Usa nomes com ano para distinguir remakes. |
| O token deixou de funcionar após recompilar | Cola-o novamente nas Definições. Uma assinatura ad-hoc diferente pode impedir o acesso ao item do Porta-chaves. Não introduzas a password do Mac no campo TMDB. |
| SRT inválido | Confirma que tem tempos e texto, não é HTML descarregado com extensão SRT; UTF-8 é preferível. |
| Sem legendas no VLC | Seleciona a faixa **Legendas Cinema**. A inclusão da faixa não corrige preferências do leitor ou sincronização errada. |
| Mobile não abre | Mac acordado, app e catálogo ativos, disco ligado, mesma rede, permissões/firewall; redes de convidados podem bloquear o acesso. |
| O atalho deixou de abrir | O IP do Mac pode ter mudado; volta a ler o QR. |
| Mobile mostra o visual antigo | Atualiza o Safari ou fecha e reabre o atalho depois de atualizar/reiniciar a app do Mac. |
| Falta espaço ao preparar | Liberta cópias no painel ou na ficha; a cópia pode ocupar o tamanho do filme. |
| TV tem som sem imagem | Desliga a saída apenas de áudio e experimenta **Duplicar ecrã** na Central de Controlo, se existir um recetor compatível. |

Para reportar um erro, inclui versão do macOS, arquitetura do Mac, versão Swift/VLC e passos de reprodução. Não envies filmes, tokens, QR codes ou o teu `library.json`. Se houver um erro de FFmpeg, remove caminhos privados do texto antes de o partilhar.
