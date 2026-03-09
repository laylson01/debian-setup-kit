#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Debian Workstation Bootstrap
# Programação, Redes, Automação e Embedded
# ==========================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"
# shellcheck source=lib/apt.sh
source "$SCRIPT_DIR/lib/apt.sh"
# shellcheck source=lib/interactive.sh
source "$SCRIPT_DIR/lib/interactive.sh"
# shellcheck source=lib/install.sh
source "$SCRIPT_DIR/lib/install.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"

on_error() {
  local exit_code=$?
  error "Falha na linha ${BASH_LINENO[0]} ao executar: ${BASH_COMMAND}"
  exit "$exit_code"
}

trap on_error ERR

if [ "$#" -eq 0 ]; then
  print_welcome
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
    --profile)
      shift
      if [ -z "${1:-}" ]; then
        error "Informe o nome do perfil após --profile."
        exit 1
      fi
      PROFILE="$1"
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
      INTERACTIVE_MODE="auto"
      ;;
    --interactive=tui)
      INTERACTIVE=true
      INTERACTIVE_MODE="tui"
      ;;
    --interactive=cli)
      INTERACTIVE=true
      INTERACTIVE_MODE="cli"
      ;;
    --no-upgrade)
      DO_UPGRADE=false
      ;;
    --skip-update)
      DO_UPDATE=false
      ;;
    --skip-upgrade)
      DO_UPGRADE=false
      ;;
    --rollback-sources)
      ROLLBACK_SOURCES=true
      ;;
    --yes|-y)
      ASSUME_YES=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --auto-fix-apt)
      AUTO_FIX_APT_MODE="apply"
      ;;
    --auto-fix-apt=preview)
      AUTO_FIX_APT_MODE="preview"
      DRY_RUN=true
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

if [ "$PROFILE" = "list" ]; then
  print_profiles
  exit 0
fi

if [ "$INTERACTIVE" = true ]; then
  if [ "$ASSUME_YES" = true ]; then
    warn "--yes ativo: modo interativo será ignorado."
  else
    interactive_select_modules
  fi
fi

if [ "$ROLLBACK_SOURCES" = true ]; then
  require_tools
  ensure_privileges
  rollback_apt_sources
  success "Rollback concluído."
  exit 0
fi

case "$PROFILE" in
  none|minimal-server|list)
    ;;
  *)
    error "Perfil inválido: $PROFILE"
    error "Perfis disponíveis: minimal-server (ou use --profile list)"
    exit 1
    ;;
esac

require_tools
ensure_any_module_selected
print_welcome
print_summary
ensure_privileges
confirm_execution

log "Atualizando índices do APT..."
if [ "$DO_UPDATE" = true ] && [ "$DRY_RUN" = false ]; then
  "${APT_CMD[@]}" update
  ensure_apt_release_consistency
  ensure_apt_health
elif [ "$DO_UPDATE" = false ]; then
  warn "apt update foi ignorado por opção (--skip-update)."
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
[ "$PROFILE" = "minimal-server" ] && install_packages "profile:minimal-server" "${MINIMAL_SERVER_PACKAGES[@]}"

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
