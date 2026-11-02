# Segurança e privacidade

Cinema destina-se a uma rede local de confiança, não a alojamento público.

- A biblioteca JSON guarda caminhos de ficheiros e preferências locais; não a publiques.
- O token TMDB é usado em pedidos HTTPS ao TMDB e guardado no Porta-chaves quando possível; a app mantém uma cópia em memória por sessão. Nunca guarda a password do Mac.
- Consultas de metadados enviam os títulos pesquisados ao TMDB. As capas são carregadas dos servidores de imagens TMDB.
- O catálogo usa HTTP local, sem TLS. Um código aleatório no URL dá acesso, mas não encripta o tráfego nem constitui uma conta de utilizador.
- Quem tiver o URL e acesso de rede pode ver a biblioteca, reproduzir cópias preparadas e alterar favoritos/coleções. Não publiques capturas do QR ou o link.
- Não configures redirecionamento de portas, túneis públicos ou acesso externo. O filtro de endereços privados não substitui uma firewall e uma rede de confiança.
- Desativar o catálogo/fechar o Cinema termina o servidor; o código do catálogo é persistente e não é revogado simplesmente ao reiniciar. Se a ligação tiver sido exposta, mantém o catálogo desativado até rodares o código local com assistência técnica. Não publiques as preferências ao pedir ajuda.
- Ficheiros originais não devem ser alterados pela preparação; as cópias ocupam armazenamento temporário. Saídas abruptas podem deixar temporários.
- O bundle gerado localmente não é notarizado. Não são incluídos certificados de assinatura.

## Reportar uma vulnerabilidade

Se a opção **Security → Report a vulnerability** estiver disponível no GitHub, usa-a para detalhes sensíveis. Se não estiver, abre apenas um issue a pedir um canal privado, sem publicar o exploit, tokens ou dados pessoais. Não há promessa de resposta num prazo definido.

Para contribuições, usa fixtures sintéticas. Não testes contra redes ou equipamentos de terceiros sem autorização.
