#!/usr/bin/env bash

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

show_help() {
  cat <<'EOH'
Uso:
  ./setup.sh [opções]

Opções:
  --all           Instala todos os módulos
  --profile NAME  Aplica um perfil pronto (ex.: minimal-server) ou lista com 'list'
  --base          Instala base do sistema
  --terminal      Instala utilitários de terminal
  --dev           Instala ferramentas de desenvolvimento
  --network       Instala ferramentas de rede
  --automation    Instala ferramentas de automação
  --embedded      Instala ferramentas para ESP32/embedded
  --optional      Instala pacotes opcionais
  --desktop-basic Instala apps básicos para usuário final (browser, mídia, e-mail)
  --desktop-full  Instala desktop completo para usuário final
  --list-packages Lista pacotes por stack e sai
  --interactive              Seleciona stacks por teclado (auto)
  --interactive=tui          Força checklist com whiptail
  --interactive=cli          Força seleção por números no terminal
  --auto-fix-apt              Corrige automaticamente sources APT Debian desalinhadas
  --auto-fix-apt=preview      Mostra o que seria alterado, sem modificar o sistema
  --rollback-sources          Restaura o backup mais recente das sources APT
  --skip-update   Não executa apt update
  --skip-upgrade  Não executa apt upgrade
  --no-upgrade    Alias de --skip-upgrade
  --yes, -y       Executa sem prompts de confirmação
  --dry-run       Mostra ações, mas não instala
  --help, -h      Mostra esta ajuda

Exemplos:
  ./setup.sh --all
  ./setup.sh --profile list
  ./setup.sh --profile minimal-server
  ./setup.sh --rollback-sources
  ./setup.sh --base --dev --network
  ./setup.sh --list-packages
  ./setup.sh --desktop-basic
  ./setup.sh --desktop-full
  ./setup.sh --interactive
  ./setup.sh --interactive=cli
  ./setup.sh --terminal --automation --embedded
  ./setup.sh --auto-fix-apt --dev
  ./setup.sh --auto-fix-apt=preview --dev
  ./setup.sh --all --dry-run
EOH
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
  echo "  DesktopBasic: $INSTALL_DESKTOP_BASIC"
  echo "  DesktopFull:  $INSTALL_DESKTOP_FULL"
  echo "  Profile:    $PROFILE"
  echo "  Update:     $DO_UPDATE"
  echo "  Upgrade:    $DO_UPGRADE"
  echo "  Dry-run:    $DRY_RUN"
  echo "  Assume-yes: $ASSUME_YES"
  echo "  Auto-fix:   $AUTO_FIX_APT_MODE"
  echo
}

print_profiles() {
  echo
  echo "Perfis disponíveis:"
  echo "  - minimal-server"
  echo
}

print_package_catalog() {
  echo
  echo "Pacotes por stack:"

  echo
  echo "[base]"
  printf ' - %s\n' "${BASE_PACKAGES[@]}"

  echo
  echo "[terminal]"
  printf ' - %s\n' "${TERMINAL_PACKAGES[@]}"

  echo
  echo "[dev]"
  printf ' - %s\n' "${DEV_PACKAGES[@]}"

  echo
  echo "[network]"
  printf ' - %s\n' "${NETWORK_PACKAGES[@]}"

  echo
  echo "[automation]"
  printf ' - %s\n' "${AUTOMATION_PACKAGES[@]}"

  echo
  echo "[embedded]"
  printf ' - %s\n' "${EMBEDDED_PACKAGES[@]}"

  echo
  echo "[optional]"
  printf ' - %s\n' "${OPTIONAL_PACKAGES[@]}"

  echo
  echo "[desktop-basic]"
  printf ' - %s\n' "${DESKTOP_BASIC_PACKAGES[@]}"

  echo
  echo "[desktop-full]"
  printf ' - %s\n' "${DESKTOP_FULL_PACKAGES[@]}"

  echo
  echo "[profile:minimal-server]"
  printf ' - %s\n' "${MINIMAL_SERVER_PACKAGES[@]}"
  echo
}

confirm_execution() {
  if [ "$DRY_RUN" = true ] || [ "$ASSUME_YES" = true ]; then
    return
  fi

  local answer=""
  read -r -p "Este comando vai alterar o sistema. Deseja continuar? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      warn "Execução cancelada pelo usuário."
      exit 0
      ;;
  esac
}

print_welcome() {
  echo
  echo "  ███████╗███████╗████████╗██╗   ██╗██████╗ "
  echo "  ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
  echo "  ███████╗█████╗     ██║   ██║   ██║██████╔╝"
  echo "  ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
  echo "  ███████║███████╗   ██║   ╚██████╔╝██║     "
  echo "  ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
  echo "============================================"
  echo "Stacks disponíveis:"
  echo "  - base"
  echo "  - terminal"
  echo "  - dev"
  echo "  - network"
  echo "  - automation"
  echo "  - embedded"
  echo "  - optional"
  echo "  - desktop-basic"
  echo "  - desktop-full"
  echo "============================================"
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
