# Debian Workstation Bootstrap

Script modular para preparar uma workstation Debian para uso em:

- programação
- redes
- automação
- ESP32 / embedded
- utilitários de terminal

O objetivo é deixar uma instalação nova do Debian pronta para estudo e trabalho, com foco em produtividade e ambiente técnico.

## Recursos

- instalação modular por grupos de pacotes
- suporte a `--dry-run`
- checagem de pacotes já instalados
- logs coloridos
- tratamento de erro com indicação de linha/comando
- validação de consistência de release Debian (sistema x repositórios)
- validação de integridade do APT antes da instalação
- opção `--auto-fix-apt` para alinhar automaticamente sources Debian
- opção `--auto-fix-apt=preview` para mostrar alterações sem aplicar
- criação de diretórios úteis
- habilitação automática do SSH quando instalado

## Requisitos

- Debian ou derivado com `apt-get`
- `sudo` instalado (quando não executar como `root`)
- acesso à internet

## Estrutura dos módulos

### `--base`
Pacotes essenciais do sistema:

- `ca-certificates`
- `curl`
- `wget`
- `gnupg`
- `lsb-release`
- `sudo`

### `--terminal`
Ferramentas úteis para terminal e produtividade:

- `vim`, `nano`, `less`
- `tmux`, `screen`
- `tree`, `file`, `jq`
- `ripgrep`, `fd-find`, `fzf`
- `htop`, `btop`, `ncdu`
- `rsync`, `zip`, `unzip`, `p7zip-full`

### `--dev`
Ferramentas de desenvolvimento:

- `git`
- `build-essential`
- `gcc`, `g++`, `make`
- `cmake`, `ninja-build`, `pkg-config`
- `gdb`, `valgrind`
- `shellcheck`, `shfmt`
- `sqlite3`
- `python3`, `python3-pip`, `python3-venv`, `pipx`

### `--network`
Ferramentas para redes e troubleshooting:

- `iproute2`, `net-tools`
- `dnsutils`, `traceroute`, `mtr-tiny`
- `nmap`, `tcpdump`
- `socat`, `netcat-openbsd`
- `ethtool`, `whois`
- `openssh-client`, `openssh-server`, `sshpass`

### `--automation`
Ferramentas para automação:

- `cron`
- `ansible`
- `ansible-lint`

### `--embedded`
Pacotes úteis para ESP32 e ambiente embedded:

- `python3`, `python3-pip`, `python3-venv`
- `cmake`, `ninja-build`, `ccache`
- `libffi-dev`, `libssl-dev`
- `dfu-util`, `libusb-1.0-0`
- `minicom`, `picocom`

### `--optional`
Pacotes extras:

- `ufw`
- `flatpak`

## Como usar

Primeiro, dê permissão de execução:

```bash
chmod +x setup.sh
```

### Testar sem instalar nada

```bash
./setup.sh --all --dry-run
```

### Instalar tudo

```bash
./setup.sh --all
```

### Instalar apenas módulos específicos

```bash
./setup.sh --base --terminal --dev --network --embedded
```

### Instalar sem executar `upgrade`

```bash
./setup.sh --all --no-upgrade
```

### Corrigir sources Debian automaticamente (iniciante)

```bash
./setup.sh --auto-fix-apt --dev
```

Quando houver desalinhamento entre codename do sistema e repositórios Debian, o script:

- cria backup de `/etc/apt/sources.list*`
- tenta alinhar as entradas Debian para o codename do sistema
- executa `apt update` novamente

### Ver prévia da correção (sem alterar nada)

```bash
./setup.sh --auto-fix-apt=preview --dev
```

## Exemplos práticos

### Workstation para desenvolvimento

```bash
./setup.sh --base --terminal --dev
```

### Máquina para redes e automação

```bash
./setup.sh --base --terminal --network --automation
```

### Ambiente para estudar ESP32

```bash
./setup.sh --base --terminal --dev --embedded
```

## Diretórios criados

Quando executado sem `--dry-run`, o script cria:

- `~/Projetos`
- `~/Labs`
- `~/Scripts`
- `~/Downloads/tools`
- `~/Embedded`
- `~/Embedded/esp32`

## Boas práticas

Antes de rodar em uma máquina principal, teste com:

```bash
./setup.sh --all --dry-run
```

Também é recomendado revisar os pacotes do módulo `--optional` para ajustar ao seu uso.

## Limitações e comportamento esperado

- O script foi feito para Debian/derivados com `apt-get`, `dpkg` e `sudo` (ou execução como `root`).
- O script bloqueia execução quando detecta mistura de releases Debian nos repositórios APT (ou tenta corrigir com `--auto-fix-apt`).
- Com `--auto-fix-apt=preview`, o script apenas exibe o diff das mudanças sugeridas.
- O script também bloqueia quando o `apt-get check` detecta dependências quebradas.
- A habilitação automática do SSH depende de `systemctl` (ambientes sem `systemd` podem exigir configuração manual do serviço).
- Um pacote é considerado instalado apenas quando está no estado `install ok installed`.

## Publicação no GitHub

Depois de criar o repositório no GitHub, use:

```bash
git init
git add .
git commit -m "feat: add Debian workstation bootstrap"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/debian-workstation-bootstrap.git
git push -u origin main
```

## Licença

Este projeto inclui licença MIT.
