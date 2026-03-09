# Debian Setup Kit

Script para preparar Debian de forma rápida e simples.

Funciona para:
- workstation (dev, terminal, rede, automação, embedded)
- servidor minimal (`minimal-server`)

## Comece em 30 segundos

```bash
chmod +x setup.sh
./setup.sh --help
```

Teste sem instalar nada:

```bash
./setup.sh --all --dry-run
```

## Comandos mais usados

Instalar tudo:

```bash
./setup.sh --all
```

Escolher stacks no teclado:

```bash
./setup.sh --interactive
```

Perfil de servidor minimal:

```bash
./setup.sh --profile minimal-server
```

Listar perfis disponíveis:

```bash
./setup.sh --profile list
```

## Correção de repositórios APT (quando necessário)

Aplicar correção automática:

```bash
./setup.sh --auto-fix-apt --dev
```

Ver prévia sem alterar o sistema:

```bash
./setup.sh --auto-fix-apt=preview --dev
```

Restaurar último backup de sources:

```bash
./setup.sh --rollback-sources
```

## Flags úteis

- `--dry-run`: mostra o que faria, sem instalar
- `--skip-update`: pula `apt update`
- `--skip-upgrade`: pula `apt upgrade`
- `--yes` / `-y`: executa sem pergunta de confirmação

## Stacks disponíveis

- `--base`
- `--terminal`
- `--dev`
- `--network`
- `--automation`
- `--embedded`
- `--optional`

Exemplo com stacks específicas:

```bash
./setup.sh --base --terminal --dev
```

## Requisitos

- Debian/derivado com `apt-get` e `dpkg`
- `sudo` (quando não executar como `root`)
- internet

## Segurança e comportamento

- O script valida conflitos de release APT.
- Se usar `--auto-fix-apt`, ele cria backup das sources antes.
- `--auto-fix-apt=preview` ativa modo seguro (`dry-run`).

## Licença

MIT
