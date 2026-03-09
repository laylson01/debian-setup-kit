#!/usr/bin/env bash

ensure_any_module_selected() {
  if ! $INSTALL_BASE && ! $INSTALL_TERMINAL && ! $INSTALL_DEV && ! $INSTALL_NETWORK && ! $INSTALL_AUTOMATION && ! $INSTALL_EMBEDDED && ! $INSTALL_OPTIONAL && [ "$PROFILE" = "none" ]; then
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

  if [ "$INTERACTIVE_MODE" != "cli" ] && command -v whiptail >/dev/null 2>&1; then
    local choices
    choices="$(
      whiptail --title "Debian Bootstrap" \
        --checklist "Use ESPAÇO para marcar; TAB vai para <Ok>; ENTER confirma." \
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

  if [ "$INTERACTIVE_MODE" = "tui" ] && ! command -v whiptail >/dev/null 2>&1; then
    error "Modo --interactive=tui requer 'whiptail', mas ele não está instalado."
    exit 1
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
