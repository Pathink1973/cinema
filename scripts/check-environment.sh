#!/bin/zsh
# Diagnóstico apenas: não instala dependências nem altera preferências.
set -eu
missing=0
if [[ "$(uname -s)" != Darwin ]]; then
  print 'Cinema requer macOS 14 ou superior.'
  exit 1
fi
print "macOS: $(sw_vers -productVersion)"
major=$(sw_vers -productVersion | cut -d. -f1)
if (( major < 14 )); then print 'Falta macOS 14+.'; missing=1; fi
if command -v swift >/dev/null 2>&1; then
  swift --version
  if ! swift --version | /usr/bin/grep -Eq 'Swift version ([6-9]|[1-9][0-9]+)\.'; then
    print 'É necessário Swift 6 ou superior.'; missing=1
  fi
else
  print 'Faltam ferramentas Swift. Consulta docs/INSTALACAO.md.'; missing=1
fi
if command -v git >/dev/null 2>&1; then git --version; else print 'Falta Git.'; missing=1; fi
if [[ -d /Applications/VLC.app || -d "$HOME/Applications/VLC.app" ]]; then
  print 'VLC: encontrado.'
else
  print 'VLC: instala a aplicação para reproduzir os filmes (não impede compilar).'
fi
for tool in ffmpeg ffprobe; do
  found=0
  for root in /opt/homebrew/bin /usr/local/bin; do
    if [[ -x "$root/$tool" ]]; then print "$tool: $root/$tool"; found=1; break; fi
  done
  if (( !found )); then
    print "$tool: não encontrado nos locais usados pelo Cinema. Necessário para mobile e testes de media."
    missing=1
  fi
done
if (( missing )); then print 'Consulta docs/INSTALACAO.md para concluir a configuração.'; exit 1; fi
print 'Ambiente pronto para compilar e executar os testes.'
