# Changelog

## v1.0.0 - 2026-03-09

Primeira versão pública para comunidade.

### Added

- Instalação modular por stacks (`base`, `terminal`, `dev`, `network`, `automation`, `embedded`, `optional`)
- Perfil pronto `minimal-server`
- Modo interativo (`--interactive`, `--interactive=tui`, `--interactive=cli`)
- Auto-correção de sources APT (`--auto-fix-apt`)
- Prévia segura de ajuste APT (`--auto-fix-apt=preview`)
- Rollback de sources (`--rollback-sources`)
- Flags de automação (`--yes`, `--skip-update`, `--skip-upgrade`)
- Saída com resumo de pacotes instalados e sugestão de `autoremove`

### Changed

- Refatoração para arquitetura modular em `lib/*.sh`
- README simplificado para onboarding rápido
