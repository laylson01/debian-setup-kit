# Debian Setup Kit

[![CI](https://github.com/laylson01/debian-setup-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/laylson01/debian-setup-kit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/badge/release-v1.0.0-blue)](./CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)

Script para preparar Debian de forma rápida e simples.

Funciona para:
- workstation (dev, terminal, rede, automação, embedded, gaming)
- servidor minimal (`minimal-server`)

## Compatibilidade

- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Debian 13 (Trixie)

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

Listar todos os pacotes por stack (sem instalar):

```bash
./setup.sh --list-packages
```

Stack para usuário comum (desktop):

```bash
./setup.sh --desktop-basic
```

Desktop completo para usuário comum:

```bash
./setup.sh --desktop-full
```

Stack completa para jogos:

```bash
./setup.sh --gaming
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
- `--list-packages`: mostra pacotes por stack e sai

## Stacks disponíveis

- `--base`
- `--terminal`
- `--dev`
- `--network`
- `--automation`
- `--embedded`
- `--gaming`
- `--optional`
- `--desktop-basic`
- `--desktop-full`

Exemplo com stacks específicas:

```bash
./setup.sh --base --terminal --dev
```

## Pacotes por stack

### `--base`

- `ca-certificates`
- `curl`
- `wget`
- `gnupg`
- `lsb-release`
- `sudo`

### `--terminal`

- `vim`
- `nano`
- `less`
- `bash-completion`
- `tmux`
- `screen`
- `tree`
- `file`
- `unzip`
- `zip`
- `p7zip-full`
- `rsync`
- `jq`
- `ripgrep`
- `fd-find`
- `fzf`
- `htop`
- `btop`
- `ncdu`
- `lsof`
- `strace`
- `xclip`

### `--dev`

- `git`
- `build-essential`
- `gcc`
- `g++`
- `make`
- `cmake`
- `ninja-build`
- `pkg-config`
- `gdb`
- `valgrind`
- `shellcheck`
- `shfmt`
- `sqlite3`
- `python3`
- `python3-pip`
- `python3-venv`
- `pipx`

### `--network`

- `iproute2`
- `net-tools`
- `dnsutils`
- `traceroute`
- `mtr-tiny`
- `nmap`
- `tcpdump`
- `socat`
- `netcat-openbsd`
- `ethtool`
- `whois`
- `iputils-ping`
- `openssh-client`
- `openssh-server`
- `sshpass`

### `--automation`

- `cron`
- `ansible`
- `ansible-lint`

### `--embedded`

- `git`
- `python3`
- `python3-pip`
- `python3-venv`
- `cmake`
- `ninja-build`
- `ccache`
- `libffi-dev`
- `libssl-dev`
- `dfu-util`
- `libusb-1.0-0`
- `minicom`
- `picocom`

### `--gaming`

- `steam-installer`
- `lutris`
- `retroarch`
- `wine`
- `wine64`
- `wine32`
- `winetricks`
- `gamemode`
- `mangohud`
- `gamescope`
- `goverlay`
- `vkbasalt`
- `libvulkan1`
- `mesa-vulkan-drivers`
- `vulkan-validationlayers`
- `vulkan-tools`
- `mesa-utils`
- `jstest-gtk`

### `--optional`

- `ufw`
- `flatpak`

### `--desktop-basic`

- `chromium`
- `vlc`
- `ffmpeg`
- `pavucontrol`
- `thunderbird`
- `libreoffice`
- `evince`
- `file-roller`
- `gnome-screenshot`

### `--desktop-full`

- `chromium`
- `vlc`
- `ffmpeg`
- `pavucontrol`
- `thunderbird`
- `libreoffice`
- `evince`
- `file-roller`
- `gnome-screenshot`
- `gimp`
- `gnome-disk-utility`
- `baobab`
- `remmina`
- `keepassxc`
- `transmission-gtk`
- `gparted`

### Perfil `minimal-server`

- `ca-certificates`
- `curl`
- `wget`
- `openssh-server`
- `openssh-client`
- `iproute2`
- `iputils-ping`
- `dnsutils`
- `netcat-openbsd`
- `rsync`
- `tmux`

## Observações da stack de jogos

- `steam-installer` normalmente requer repositórios `contrib`, `non-free` e `non-free-firmware`.
- A stack `--gaming` habilita `i386` automaticamente quando necessário e atualiza os índices do APT.
- Após instalar `steam-installer`, o script tenta iniciar o Steam automaticamente no usuário normal (quando detectável em sessão gráfica).
- Se o APT não conseguir resolver dependências do Steam (ex.: `steam-libs-i386`), o script agora ignora apenas esse pacote e continua os demais.
- Alguns pacotes de jogos podem não existir em todos os codenames; o script ignora automaticamente os indisponíveis.

## FAQ

### 1) `sudo: user is not in the sudoers file`

Use um usuário com permissão `sudo` ou rode como `root`.

### 2) Erro de APT desalinhado (`bookworm` x `trixie`)

Use:

```bash
./setup.sh --auto-fix-apt=preview --dev
```

Se estiver correto, aplique:

```bash
./setup.sh --auto-fix-apt --dev
```

### 3) `--interactive` não funciona no terminal

Use fallback de CLI:

```bash
./setup.sh --interactive=cli
```

## Requisitos

- Debian/derivado com `apt-get` e `dpkg`
- `sudo` (quando não executar como `root`)
- internet

## Segurança e comportamento

- O script valida conflitos de release APT.
- Se usar `--auto-fix-apt`, ele cria backup das sources antes.
- `--auto-fix-apt=preview` ativa modo seguro (`dry-run`).

## Antes de publicar/rodar em produção

- Rode `./setup.sh --all --dry-run` para validar fluxo sem alterações.
- Revise a política em [`SECURITY.md`](./SECURITY.md).
- Não versione credenciais (`.env`, chaves `.pem/.key`, tokens).
- Recomenda-se testar primeiro em VM/snapshot.

## Contribuição

Veja o guia em [`CONTRIBUTING.md`](./CONTRIBUTING.md).

## Changelog

Veja [`CHANGELOG.md`](./CHANGELOG.md).

## Licença

MIT
