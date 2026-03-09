# Security Policy

## Supported Versions

Este projeto segue o branch `main`.

## Reporting a Vulnerability

Se você encontrar uma vulnerabilidade:

1. Não abra issue pública com detalhes sensíveis.
2. Entre em contato em canal privado (e-mail/mensagem direta do mantenedor).
3. Inclua passos para reproduzir, impacto e sugestão de correção.

## Security Notes

- Nunca faça commit de tokens, chaves privadas ou arquivos `.env`.
- Sempre rode `./setup.sh --dry-run` antes da execução real em máquinas críticas.
- Use `--auto-fix-apt=preview` para revisar mudanças de repositório sem aplicar.
