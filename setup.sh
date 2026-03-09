#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Debian Workstation Bootstrap
# Programação, Redes, Automação e Embedded
# ==========================================
# Descrição:
#   Script modular para preparar uma workstation Debian para uso em
#   desenvolvimento, redes, automação e projetos com ESP32/embedded.
#
# Exemplos:
#   ./setup.sh --all
#   ./setup.sh --base --terminal --dev --network --embedded
#   ./setup.sh --all --dry-run
# ==========================================

# ---------- Cores ----------
if [[ -t 1 ]]; then
  GREEN="\033[1;32m"
  YELLOW="\033[1;33m"
  RED="\033[1;31m"
  BLUE="\033[1;34m"
  RESET="\033[0m"
else
  GREEN=""
  YELLOW=""
  RED=""
  BLUE=""
  RESET=""
fi

# ---------- Variáveis globais ----------
APT_CMD=(sudo apt-get)
export DEBIAN_FRONTEND=noninteractive

# ---------- Logging ----------
log() {
  echo -e "${BLUE}==>${RESET} $1"
}

success() {
  echo -e "${GREEN}[OK]${RESET} $1"
}

warn() {
  echo -e "${YELLOW}[AVISO]${RESET} $1"
}

error() {
  echo -e "${RED}[ERRO]${RESET} $1" >&2
}

on_error() {
  local exit_code=$?
  error "Falha na linha ${BASH_LINENO[0]} ao executar: ${BASH_COMMAND}"
  exit "$exit_code"
}

trap on_error ERR

# ---------- Ajuda ----------
show_help() {
  cat <<'EOH'
Uso:
  ./setup.sh [opções]

Opções:
  --all           Instala todos os módulos
  --base          Instala base do sistema
  --terminal      Instala utilitários de terminal
  --dev           Instala ferramentas de desenvolvimento
  --network       Instala ferramentas de rede
  --automation    Instala ferramentas de automação
  --embedded      Instala ferramentas para ESP32/embedded
  --optional      Instala pacotes opcionais
  --no-upgrade    Não executa apt upgrade
  --dry-run       Mostra ações, mas não instala
  --help, -h      Mostra esta ajuda

Exemplos:
  ./setup.sh --all
  ./setup.sh --base --dev --network
  ./setup.sh --terminal --automation --embedded
  ./setup.sh --all --dry-run
EOH
}

# ---------- Validações ----------
require_tools() {
  if ! command -v apt-get >/dev/null 2>&1; then
    error "Este script foi feito para sistemas com APT (Debian/Ubuntu)."
    exit 1
  fi

  if ! command -v dpkg >/dev/null 2>&1; then
    error "dpkg não está disponível."
    exit 1
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo não está instalado."
    exit 1
  fi
}

ensure_any_module_selected() {
  if ! $INSTALL_BASE && ! $INSTALL_TERMINAL && ! $INSTALL_DEV && ! $INSTALL_NETWORK && ! $INSTALL_AUTOMATION && ! $INSTALL_EMBEDDED && ! $INSTALL_OPTIONAL; then
    warn "Nenhum módulo selecionado."
    echo
    show_help
    exit 1
  fi
}

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

# ---------- Ações ----------
install_packages() {
  local module_name="$1"
  shift
  local packages=("$@")

  if [ "${#packages[@]}" -eq 0 ]; then
    warn "Nenhum pacote definido para o módulo: $module_name"
    return
  fi

  log "Processando módulo: $module_name"

  local missing=()
  for pkg in "${packages[@]}"; do
    if ! package_installed "$pkg"; then
      missing+=("$pkg")
    fi
  done

  if [ "${#missing[@]}" -eq 0 ]; then
    success "Todos os pacotes de '$module_name' já estão instalados."
    return
  fi

  echo "Pacotes a instalar em '$module_name':"
  printf ' - %s\n' "${missing[@]}"

  if [ "$DRY_RUN" = true ]; then
    warn "Dry-run ativo: nada será instalado."
    return
  fi

  "${APT_CMD[@]}" install -y --no-install-recommends "${missing[@]}"
  success "Módulo '$module_name' concluído."
}

create_directories() {
  log "Criando diretórios de trabalho..."
  mkdir -p \
    "$HOME/Projetos" \
    "$HOME/Labs" \
    "$HOME/Scripts" \
    "$HOME/Downloads/tools" \
    "$HOME/Embedded" \
    "$HOME/Embedded/esp32"
  success "Diretórios criados."
}

enable_ssh_if_installed() {
  if package_installed "openssh-server"; then
    log "Ativando serviço SSH..."
    if ! command -v systemctl >/dev/null 2>&1; then
      warn "systemctl não disponível; não foi possível habilitar o SSH automaticamente."
      return
    fi

    if sudo systemctl enable ssh >/dev/null 2>&1 && sudo systemctl start ssh >/dev/null 2>&1; then
      success "SSH habilitado."
    else
      warn "Não foi possível habilitar/iniciar o serviço SSH automaticamente."
    fi
  fi
}

print_summary() {
  echo
  echo "Resumo dos módulos selecionados:"
  echo "  Base:       $INSTALL_BASE"
  echo "  Terminal:   $INSTALL_TERMINAL"
  echo "  Dev:        $INSTALL_DEV"
  echo "  Network:    $INSTALL_NETWORK"
  echo "  Automation: $INSTALL_AUTOMATION"
  echo "  Embedded:   $INSTALL_EMBEDDED"
  echo "  Optional:   $INSTALL_OPTIONAL"
  echo "  Upgrade:    $DO_UPGRADE"
  echo "  Dry-run:    $DRY_RUN"
  echo
}

# ---------- Pacotes por módulo ----------
BASE_PACKAGES=(
  ca-certificates
  curl
  wget
  gnupg
  lsb-release
  sudo
)

TERMINAL_PACKAGES=(
  vim
  nano
  less
  bash-completion
  tmux
  screen
  tree
  file
  unzip
  zip
  p7zip-full
  rsync
  jq
  ripgrep
  fd-find
  fzf
  htop
  btop
  ncdu
  lsof
  strace
  xclip
)

DEV_PACKAGES=(
  git
  build-essential
  gcc
  g++
  make
  cmake
  ninja-build
  pkg-config
  gdb
  valgrind
  shellcheck
  shfmt
  sqlite3
  python3
  python3-pip
  python3-venv
  pipx
)

NETWORK_PACKAGES=(
  iproute2
  net-tools
  dnsutils
  traceroute
  mtr-tiny
  nmap
  tcpdump
  socat
  netcat-openbsd
  ethtool
  whois
  iputils-ping
  openssh-client
  openssh-server
  sshpass
)

AUTOMATION_PACKAGES=(
  cron
  ansible
  ansible-lint
)

EMBEDDED_PACKAGES=(
  git
  python3
  python3-pip
  python3-venv
  cmake
  ninja-build
  ccache
  libffi-dev
  libssl-dev
  dfu-util
  libusb-1.0-0
  minicom
  picocom
)

OPTIONAL_PACKAGES=(
  ufw
  flatpak
)

# ---------- Defaults ----------
INSTALL_BASE=false
INSTALL_TERMINAL=false
INSTALL_DEV=false
INSTALL_NETWORK=false
INSTALL_AUTOMATION=false
INSTALL_EMBEDDED=false
INSTALL_OPTIONAL=false
DO_UPGRADE=true
DRY_RUN=false

# ---------- Parse argumentos ----------
if [ "$#" -eq 0 ]; then
  show_help
  exit 0
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --all)
      INSTALL_BASE=true
      INSTALL_TERMINAL=true
      INSTALL_DEV=true
      INSTALL_NETWORK=true
      INSTALL_AUTOMATION=true
      INSTALL_EMBEDDED=true
      INSTALL_OPTIONAL=true
      ;;
    --base)
      INSTALL_BASE=true
      ;;
    --terminal)
      INSTALL_TERMINAL=true
      ;;
    --dev)
      INSTALL_DEV=true
      ;;
    --network)
      INSTALL_NETWORK=true
      ;;
    --automation)
      INSTALL_AUTOMATION=true
      ;;
    --embedded)
      INSTALL_EMBEDDED=true
      ;;
    --optional)
      INSTALL_OPTIONAL=true
      ;;
    --no-upgrade)
      DO_UPGRADE=false
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      error "Opção inválida: $1"
      echo
      show_help
      exit 1
      ;;
  esac
  shift
done

require_tools
ensure_any_module_selected
print_summary

log "Atualizando índices do APT..."
if [ "$DRY_RUN" = false ]; then
  "${APT_CMD[@]}" update
else
  warn "Dry-run ativo: apt update não será executado."
fi

if [ "$DO_UPGRADE" = true ]; then
  log "Atualizando sistema..."
  if [ "$DRY_RUN" = false ]; then
    "${APT_CMD[@]}" upgrade -y
  else
    warn "Dry-run ativo: apt upgrade não será executado."
  fi
else
  warn "Upgrade do sistema ignorado por opção."
fi

$INSTALL_BASE && install_packages "base" "${BASE_PACKAGES[@]}"
$INSTALL_TERMINAL && install_packages "terminal" "${TERMINAL_PACKAGES[@]}"
$INSTALL_DEV && install_packages "dev" "${DEV_PACKAGES[@]}"
$INSTALL_NETWORK && install_packages "network" "${NETWORK_PACKAGES[@]}"
$INSTALL_AUTOMATION && install_packages "automation" "${AUTOMATION_PACKAGES[@]}"
$INSTALL_EMBEDDED && install_packages "embedded" "${EMBEDDED_PACKAGES[@]}"
$INSTALL_OPTIONAL && install_packages "optional" "${OPTIONAL_PACKAGES[@]}"

if [ "$DRY_RUN" = false ]; then
  create_directories
  enable_ssh_if_installed
else
  warn "Dry-run ativo: diretórios e serviços não serão alterados."
fi

echo
success "Setup concluído com sucesso."
