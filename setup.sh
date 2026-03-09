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
if [ "$EUID" -eq 0 ]; then
  APT_CMD=(apt-get)
else
  APT_CMD=(sudo apt-get)
fi
export DEBIAN_FRONTEND=noninteractive
INSTALLED_THIS_RUN=()

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
  --interactive   Seleciona stacks por teclado (checklist)
  --auto-fix-apt              Corrige automaticamente sources APT Debian desalinhadas
  --auto-fix-apt=preview      Mostra o que seria alterado, sem modificar o sistema
  --no-upgrade    Não executa apt upgrade
  --dry-run       Mostra ações, mas não instala
  --help, -h      Mostra esta ajuda

Exemplos:
  ./setup.sh --all
  ./setup.sh --base --dev --network
  ./setup.sh --interactive
  ./setup.sh --terminal --automation --embedded
  ./setup.sh --auto-fix-apt --dev
  ./setup.sh --auto-fix-apt=preview --dev
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

  if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
    error "sudo não está instalado."
    exit 1
  fi
}

get_system_codename() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [ -n "${VERSION_CODENAME:-}" ]; then
      printf '%s\n' "$VERSION_CODENAME"
      return
    fi
  fi

  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -sc
    return
  fi

  printf '%s\n' ""
}

get_debian_repo_codenames() {
  local repo_suites
  repo_suites="$(
    apt-cache policy \
      | grep 'release ' \
      | grep 'o=Debian' \
      | sed -n 's/.*n=\([^, ]*\).*/\1/p' \
      | sort -u
  )"

  if [ -z "$repo_suites" ]; then
    printf '%s\n' ""
    return
  fi

  printf '%s\n' "$repo_suites" \
    | sed -E 's/-(security|updates|backports|proposed-updates)$//' \
    | sort -u
}

as_root() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

auto_fix_apt_sources() {
  local target_codename="$1"
  local backup_dir="/var/backups/debian-bootstrap-apt-$(date +%Y%m%d-%H%M%S)"

  log "Executando correção automática de sources APT para '$target_codename'..."
  log "Salvando backup em: $backup_dir"

  as_root mkdir -p "$backup_dir"
  if [ -f /etc/apt/sources.list ]; then
    as_root cp /etc/apt/sources.list "$backup_dir/sources.list"
  fi
  if [ -d /etc/apt/sources.list.d ]; then
    as_root cp -a /etc/apt/sources.list.d "$backup_dir/sources.list.d"
  fi

  if [ -f /etc/apt/sources.list ]; then
    as_root sed -E -i \
      "/^[[:space:]]*deb(-src)?[[:space:]].*(debian\\.org|debian-security)/ s/\\b(bullseye|bookworm|trixie)(-security|-updates|-backports|-proposed-updates)?\\b/${target_codename}\\2/g" \
      /etc/apt/sources.list
  fi

  if [ -d /etc/apt/sources.list.d ]; then
    while IFS= read -r file; do
      as_root sed -E -i \
        "/^[[:space:]]*deb(-src)?[[:space:]].*(debian\\.org|debian-security)/ s/\\b(bullseye|bookworm|trixie)(-security|-updates|-backports|-proposed-updates)?\\b/${target_codename}\\2/g" \
        "$file"
    done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list')
  fi

  log "Atualizando índices do APT após correção automática..."
  "${APT_CMD[@]}" update
}

preview_auto_fix_apt_sources() {
  local target_codename="$1"
  local changed=false
  local file

  log "Prévia de correção automática para '$target_codename' (sem alterações no sistema)..."

  if [ -f /etc/apt/sources.list ]; then
    local tmp
    tmp="$(mktemp)"
    sed -E \
      "/^[[:space:]]*deb(-src)?[[:space:]].*(debian\\.org|debian-security)/ s/\\b(bullseye|bookworm|trixie)(-security|-updates|-backports|-proposed-updates)?\\b/${target_codename}\\2/g" \
      /etc/apt/sources.list >"$tmp"
    if ! cmp -s /etc/apt/sources.list "$tmp"; then
      changed=true
      echo
      echo "Arquivo que mudaria: /etc/apt/sources.list"
      diff -u /etc/apt/sources.list "$tmp" || true
    fi
    rm -f "$tmp"
  fi

  if [ -d /etc/apt/sources.list.d ]; then
    while IFS= read -r file; do
      local tmp
      tmp="$(mktemp)"
      sed -E \
        "/^[[:space:]]*deb(-src)?[[:space:]].*(debian\\.org|debian-security)/ s/\\b(bullseye|bookworm|trixie)(-security|-updates|-backports|-proposed-updates)?\\b/${target_codename}\\2/g" \
        "$file" >"$tmp"
      if ! cmp -s "$file" "$tmp"; then
        changed=true
        echo
        echo "Arquivo que mudaria: $file"
        diff -u "$file" "$tmp" || true
      fi
      rm -f "$tmp"
    done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list')
  fi

  if [ "$changed" = false ]; then
    success "Prévia concluída: nenhuma mudança seria necessária nas sources Debian."
  else
    warn "Prévia concluída. Para aplicar, rode com --auto-fix-apt."
  fi
}

ensure_apt_release_consistency() {
  local system_codename
  system_codename="$(get_system_codename)"

  if [ -z "$system_codename" ]; then
    warn "Não foi possível detectar o codename do sistema; pulando checagem de consistência de release."
    return
  fi

  local repo_codenames
  repo_codenames="$(get_debian_repo_codenames)"
  if [ -z "$repo_codenames" ]; then
    warn "Não foi possível detectar codenames Debian nos repositórios; pulando checagem de consistência de release."
    return
  fi

  local codename_count
  codename_count="$(printf '%s\n' "$repo_codenames" | sed '/^$/d' | wc -l)"
  if [ "$codename_count" -gt 1 ]; then
    if [ "$AUTO_FIX_APT_MODE" = "preview" ]; then
      preview_auto_fix_apt_sources "$system_codename"
    fi

    if [ "$AUTO_FIX_APT_MODE" = "apply" ] && [ "$DRY_RUN" = false ]; then
      warn "Mistura de releases detectada. Tentando correção automática (--auto-fix-apt)..."
      auto_fix_apt_sources "$system_codename"
      repo_codenames="$(get_debian_repo_codenames)"
      codename_count="$(printf '%s\n' "$repo_codenames" | sed '/^$/d' | wc -l)"
      if [ "$codename_count" -le 1 ] && printf '%s\n' "$repo_codenames" | grep -qx "$system_codename"; then
        success "Sources APT alinhadas automaticamente para '$system_codename'."
        return
      fi
      error "A correção automática não conseguiu alinhar os repositórios Debian."
    fi

    error "Foram detectados múltiplos codenames Debian nos repositórios APT:"
    printf ' - %s\n' $repo_codenames >&2
    error "Isso indica mistura de releases e pode quebrar dependências."
    error "Ajuste os repositórios para uma única release (ou use --auto-fix-apt / --auto-fix-apt=preview)."
    exit 1
  fi

  if ! printf '%s\n' "$repo_codenames" | grep -qx "$system_codename"; then
    if [ "$AUTO_FIX_APT_MODE" = "preview" ]; then
      preview_auto_fix_apt_sources "$system_codename"
    fi

    if [ "$AUTO_FIX_APT_MODE" = "apply" ] && [ "$DRY_RUN" = false ]; then
      warn "Sistema e repositórios desalinhados. Tentando correção automática (--auto-fix-apt)..."
      auto_fix_apt_sources "$system_codename"
      repo_codenames="$(get_debian_repo_codenames)"
      if printf '%s\n' "$repo_codenames" | grep -qx "$system_codename"; then
        success "Sources APT alinhadas automaticamente para '$system_codename'."
        return
      fi
      error "A correção automática não conseguiu alinhar os repositórios Debian."
    fi

    error "Codename do sistema: $system_codename"
    error "Codename Debian detectado nos repositórios: $repo_codenames"
    error "Sistema e repositórios estão desalinhados; isso causa conflitos de dependência."
    error "Alinhe os repositórios ao codename do sistema e rode: apt update && apt --fix-broken install (ou use --auto-fix-apt / --auto-fix-apt=preview)."
    exit 1
  fi
}

ensure_apt_health() {
  log "Verificando integridade de dependências (apt-get check)..."
  if ! "${APT_CMD[@]}" check >/dev/null; then
    error "O APT detectou dependências quebradas no sistema."
    error "Corrija antes de continuar com: apt --fix-broken install && apt full-upgrade"
    exit 1
  fi
}

ensure_privileges() {
  if [ "$DRY_RUN" = true ] || [ "$EUID" -eq 0 ]; then
    return
  fi

  log "Validando privilégios sudo..."
  if ! sudo -v; then
    error "Este usuário não tem permissão sudo para instalar pacotes."
    error "Use um usuário com sudo, execute como root, ou peça acesso ao administrador."
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

bool_to_onoff() {
  if [ "$1" = true ]; then
    printf 'ON\n'
  else
    printf 'OFF\n'
  fi
}

reset_module_selection() {
  INSTALL_BASE=false
  INSTALL_TERMINAL=false
  INSTALL_DEV=false
  INSTALL_NETWORK=false
  INSTALL_AUTOMATION=false
  INSTALL_EMBEDDED=false
  INSTALL_OPTIONAL=false
}

interactive_select_modules() {
  log "Modo interativo: selecione os stacks desejados."

  local base_state terminal_state dev_state network_state automation_state embedded_state optional_state
  base_state="$(bool_to_onoff "$INSTALL_BASE")"
  terminal_state="$(bool_to_onoff "$INSTALL_TERMINAL")"
  dev_state="$(bool_to_onoff "$INSTALL_DEV")"
  network_state="$(bool_to_onoff "$INSTALL_NETWORK")"
  automation_state="$(bool_to_onoff "$INSTALL_AUTOMATION")"
  embedded_state="$(bool_to_onoff "$INSTALL_EMBEDDED")"
  optional_state="$(bool_to_onoff "$INSTALL_OPTIONAL")"

  reset_module_selection

  if command -v whiptail >/dev/null 2>&1; then
    local choices
    choices="$(
      whiptail --title "Debian Bootstrap" \
        --checklist "Use ESPAÇO para marcar, setas para navegar e ENTER para confirmar." \
        20 90 10 \
        "BASE" "Base do sistema" "$base_state" \
        "TERMINAL" "Utilitários de terminal" "$terminal_state" \
        "DEV" "Ferramentas de desenvolvimento" "$dev_state" \
        "NETWORK" "Ferramentas de rede" "$network_state" \
        "AUTOMATION" "Ferramentas de automação" "$automation_state" \
        "EMBEDDED" "Ferramentas para ESP32/embedded" "$embedded_state" \
        "OPTIONAL" "Pacotes opcionais" "$optional_state" \
        3>&1 1>&2 2>&3
    )" || {
      error "Seleção interativa cancelada."
      exit 1
    }

    for item in $choices; do
      case "${item//\"/}" in
        BASE) INSTALL_BASE=true ;;
        TERMINAL) INSTALL_TERMINAL=true ;;
        DEV) INSTALL_DEV=true ;;
        NETWORK) INSTALL_NETWORK=true ;;
        AUTOMATION) INSTALL_AUTOMATION=true ;;
        EMBEDDED) INSTALL_EMBEDDED=true ;;
        OPTIONAL) INSTALL_OPTIONAL=true ;;
      esac
    done
    return
  fi

  warn "whiptail não encontrado. Usando fallback por números."
  echo "Selecione os stacks (ex.: 1 3 4):"
  echo "  1) Base"
  echo "  2) Terminal"
  echo "  3) Dev"
  echo "  4) Network"
  echo "  5) Automation"
  echo "  6) Embedded"
  echo "  7) Optional"

  local picks=()
  read -r -a picks

  local pick
  for pick in "${picks[@]}"; do
    case "$pick" in
      1) INSTALL_BASE=true ;;
      2) INSTALL_TERMINAL=true ;;
      3) INSTALL_DEV=true ;;
      4) INSTALL_NETWORK=true ;;
      5) INSTALL_AUTOMATION=true ;;
      6) INSTALL_EMBEDDED=true ;;
      7) INSTALL_OPTIONAL=true ;;
      *)
        warn "Opção ignorada no modo fallback: $pick"
        ;;
    esac
  done
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
  INSTALLED_THIS_RUN+=("${missing[@]}")
  echo "Pacotes instalados em '$module_name':"
  printf ' - %s\n' "${missing[@]}"
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

    if as_root systemctl enable ssh >/dev/null 2>&1 && as_root systemctl start ssh >/dev/null 2>&1; then
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
  echo "  Auto-fix:   $AUTO_FIX_APT_MODE"
  echo
}

print_installed_summary() {
  if [ "${#INSTALLED_THIS_RUN[@]}" -eq 0 ]; then
    warn "Nenhum novo pacote foi instalado nesta execução."
    return
  fi

  echo
  echo "Pacotes instalados nesta execução (${#INSTALLED_THIS_RUN[@]}):"
  printf ' - %s\n' "${INSTALLED_THIS_RUN[@]}"
}

suggest_autoremove_if_needed() {
  local removable=()
  while IFS= read -r pkg; do
    removable+=("$pkg")
  done < <("${APT_CMD[@]}" -s autoremove 2>/dev/null | sed -n 's/^Remv[[:space:]]\+\([^[:space:]]\+\).*/\1/p')

  if [ "${#removable[@]}" -gt 0 ]; then
    echo
    warn "Foram detectados ${#removable[@]} pacotes que podem ser removidos com segurança:"
    printf ' - %s\n' "${removable[@]}"
    warn "Sugestão: execute '${APT_CMD[*]} autoremove'"
  fi
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
AUTO_FIX_APT_MODE="off"
INTERACTIVE=false

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
    --interactive)
      INTERACTIVE=true
      ;;
    --no-upgrade)
      DO_UPGRADE=false
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --auto-fix-apt)
      AUTO_FIX_APT_MODE="apply"
      ;;
    --auto-fix-apt=preview)
      AUTO_FIX_APT_MODE="preview"
      ;;
    --auto-fix-apt=apply)
      AUTO_FIX_APT_MODE="apply"
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

if [ "$INTERACTIVE" = true ]; then
  interactive_select_modules
fi

require_tools
ensure_any_module_selected
print_summary
ensure_privileges

log "Atualizando índices do APT..."
if [ "$DRY_RUN" = false ]; then
  "${APT_CMD[@]}" update
  ensure_apt_release_consistency
  ensure_apt_health
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
  print_installed_summary
  suggest_autoremove_if_needed
else
  warn "Dry-run ativo: diretórios e serviços não serão alterados."
fi

echo
success "Setup concluído com sucesso."
