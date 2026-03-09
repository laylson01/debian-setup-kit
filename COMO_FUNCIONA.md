# Como o `setup.sh` funciona (passo a passo)

Este documento explica o script [`setup.sh`](/home/laylson/Downloads/debian-bootstrap/setup.sh) de ponta a ponta: o que ele faz, em que ordem faz, quais opções existem e o que esperar em cada etapa.

## 1. Objetivo do projeto

O script automatiza a preparação de uma workstation Debian/derivados para:

- terminal e produtividade
- desenvolvimento
- redes
- automação
- embedded/ESP32

Ele é modular: você escolhe só os módulos que quer instalar.

## 2. Pré-requisitos

Antes de executar, o ambiente precisa ter:

- sistema com `apt-get` (Debian/derivado)
- `dpkg`
- `sudo`
- internet para baixar pacotes

## 3. Visão geral do fluxo

Quando você roda o script, ele segue esta ordem:

1. Carrega configurações iniciais (`set -Eeuo pipefail`, cores, variáveis globais).
2. Faz parse dos argumentos (`--base`, `--dev`, `--all`, etc.).
3. Valida ferramentas obrigatórias (`apt-get`, `dpkg`, `sudo`).
4. Garante que ao menos um módulo foi selecionado.
5. Mostra resumo das opções escolhidas.
6. Executa `apt update` (exceto em `--dry-run`).
7. Valida consistência de release Debian (codename do sistema x repositórios).
8. Executa `apt-get check` para validar saúde das dependências.
9. Executa `apt upgrade -y` (a menos que `--no-upgrade` ou `--dry-run`).
10. Processa os módulos selecionados e instala apenas pacotes faltantes.
11. Se não for `--dry-run`, cria diretórios de trabalho.
12. Se `openssh-server` estiver instalado, tenta habilitar/iniciar SSH.
13. Mostra mensagem final de sucesso.

## 4. Opções disponíveis

- `--all`: ativa todos os módulos.
- `--base`: pacote base do sistema.
- `--terminal`: ferramentas de terminal.
- `--dev`: ferramentas de desenvolvimento.
- `--network`: ferramentas de rede.
- `--automation`: ferramentas de automação.
- `--embedded`: ferramentas para ESP32/embedded.
- `--optional`: pacotes opcionais.
- `--no-upgrade`: não roda `apt upgrade`.
- `--dry-run`: simula, não altera sistema.
- `--help` / `-h`: ajuda.

## 5. Passo a passo interno (detalhado)

## 5.1 Tratamento de erro e segurança

O script inicia com:

- `set -Eeuo pipefail`: para falhar cedo em erros reais.
- `trap on_error ERR`: imprime linha e comando que falhou.

Isso evita execuções silenciosamente incompletas.

## 5.2 Parse dos argumentos

Cada flag altera variáveis booleanas internas:

- `INSTALL_BASE`, `INSTALL_DEV`, etc.
- `DO_UPGRADE` (por padrão `true`)
- `DRY_RUN` (por padrão `false`)

Sem argumentos, o script mostra ajuda e sai.

## 5.3 Validação inicial

Função `require_tools()`:

- aborta se não houver `apt-get`
- aborta se não houver `dpkg`
- aborta se não houver `sudo`

Função `ensure_any_module_selected()`:

- aborta se nenhum módulo foi marcado

## 5.4 Resumo da execução

Antes de instalar, o script imprime um resumo com:

- módulos ativos/inativos
- se haverá `upgrade`
- se é `dry-run`

## 5.5 Atualização, consistência e integridade

- Sempre tenta `apt update` (exceto `--dry-run`).
- Valida se os repositórios Debian usam o mesmo codename do sistema (ex.: tudo `bookworm`).
- Bloqueia se detectar mistura de releases (ex.: `bookworm` + `trixie`).
- Executa `apt-get check` para detectar dependências quebradas antes da instalação.
- Só então segue para `apt upgrade -y` quando `DO_UPGRADE=true`.

## 5.6 Instalação por módulo

Cada módulo chama `install_packages "nome" "${PACOTES[@]}"`.

A função faz:

1. monta lista de pacotes faltantes
2. considera instalado somente status `install ok installed`
3. se nada faltar, informa e segue
4. se `--dry-run`, só mostra o que instalaria
5. se execução real, roda `sudo apt-get install -y --no-install-recommends ...`

## 5.7 Pós-instalação

Se não estiver em `--dry-run`:

- cria diretórios:
  - `~/Projetos`
  - `~/Labs`
  - `~/Scripts`
  - `~/Downloads/tools`
  - `~/Embedded`
  - `~/Embedded/esp32`
- tenta habilitar/iniciar SSH, se `openssh-server` estiver instalado

Sobre SSH:

- se `systemctl` não existir, mostra aviso
- se `enable/start` falhar, mostra aviso (sem falso sucesso)

## 6. O que cada módulo instala

## 6.1 `--base`

Essenciais:

- `ca-certificates`, `curl`, `wget`, `gnupg`, `lsb-release`, `sudo`

## 6.2 `--terminal`

Produtividade no terminal:

- editores e sessão (`vim`, `nano`, `tmux`, `screen`)
- navegação e utilitários (`tree`, `file`, `jq`, `rsync`, `zip`, `unzip`)
- busca e navegação rápida (`ripgrep`, `fd-find`, `fzf`)
- monitoramento (`htop`, `btop`, `ncdu`, `lsof`, `strace`)

## 6.3 `--dev`

Desenvolvimento geral:

- compilação (`build-essential`, `gcc`, `g++`, `make`)
- build tooling (`cmake`, `ninja-build`, `pkg-config`)
- debug/qualidade (`gdb`, `valgrind`, `shellcheck`, `shfmt`)
- Python (`python3`, `pip`, `venv`, `pipx`)

## 6.4 `--network`

Rede e troubleshooting:

- conectividade e diagnóstico (`iproute2`, `net-tools`, `dnsutils`, `traceroute`, `mtr-tiny`)
- análise (`nmap`, `tcpdump`, `socat`, `netcat-openbsd`)
- SSH (`openssh-client`, `openssh-server`, `sshpass`)

## 6.5 `--automation`

Automação:

- `cron`, `ansible`, `ansible-lint`

## 6.6 `--embedded`

Base para embedded/ESP32:

- toolchain e libs (`cmake`, `ninja-build`, `ccache`, `libffi-dev`, `libssl-dev`)
- comunicação/dispositivos (`dfu-util`, `libusb-1.0-0`, `minicom`, `picocom`)

## 6.7 `--optional`

Extras:

- `ufw`, `flatpak`

## 7. Exemplos de execução (passo a passo)

## 7.1 Simular tudo

```bash
./setup.sh --all --dry-run
```

O que acontece:

1. valida ferramentas
2. imprime resumo
3. não roda `apt update/upgrade`
4. mostra pacotes que instalaria por módulo
5. não cria diretórios, não altera serviços

## 7.2 Instalar ambiente de desenvolvimento

```bash
./setup.sh --base --terminal --dev
```

O que acontece:

1. `apt update`
2. `apt upgrade -y`
3. instala pacotes faltantes dos 3 módulos
4. cria diretórios
5. tenta configurar SSH se `openssh-server` existir

## 7.3 Instalar tudo sem upgrade

```bash
./setup.sh --all --no-upgrade
```

O que acontece:

1. `apt update`
2. pula `upgrade`
3. instala pacotes faltantes de todos os módulos
4. pós-configuração normal

## 8. Como validar antes de usar em produção

Checklist recomendado:

1. `bash -n setup.sh` para validar sintaxe.
2. `./setup.sh --all --dry-run` para validar fluxo.
3. Revisar módulos opcionais (`--optional`) antes de instalar.
4. Executar primeiro em VM/lab.

## 9. Limitações conhecidas

- Depende de APT (`apt-get`/`dpkg`), não é script universal Linux.
- Em ambientes sem `systemd`, a etapa automática de SSH pode não funcionar.
- O foco é instalação de pacotes via repositórios oficiais, sem setup avançado por linguagem/framework.

## 10. Arquivos principais do projeto

- Script principal: [`setup.sh`](/home/laylson/Downloads/debian-bootstrap/setup.sh)
- Guia de uso rápido: [`README.md`](/home/laylson/Downloads/debian-bootstrap/README.md)
- Licença: [`LICENSE`](/home/laylson/Downloads/debian-bootstrap/LICENSE)
