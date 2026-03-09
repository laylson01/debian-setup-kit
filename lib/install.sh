#!/usr/bin/env bash

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

  local installable=()
  local unavailable=()
  for pkg in "${missing[@]}"; do
    if package_installable "$pkg"; then
      installable+=("$pkg")
    else
      unavailable+=("$pkg")
    fi
  done

  if [ "${#installable[@]}" -eq 0 ]; then
    warn "Nenhum pacote instalável foi encontrado no módulo '$module_name'."
    if [ "${#unavailable[@]}" -gt 0 ]; then
      warn "Pacotes indisponíveis ou com dependências não resolvidas:"
      printf ' - %s\n' "${unavailable[@]}"
    fi
    return
  fi

  echo "Pacotes a instalar em '$module_name':"
  printf ' - %s\n' "${installable[@]}"
  if [ "${#unavailable[@]}" -gt 0 ]; then
    warn "Pacotes indisponíveis ou com dependências não resolvidas (serão ignorados):"
    printf ' - %s\n' "${unavailable[@]}"
  fi

  if [ "$DRY_RUN" = true ]; then
    warn "Dry-run ativo: nada será instalado."
    return
  fi

  "${APT_CMD[@]}" install -y --no-install-recommends "${installable[@]}"

  local installed_now=()
  for pkg in "${installable[@]}"; do
    if package_installed "$pkg"; then
      installed_now+=("$pkg")
    fi
  done

  if [ "${#installed_now[@]}" -gt 0 ]; then
    INSTALLED_THIS_RUN+=("${installed_now[@]}")
    echo "Pacotes instalados em '$module_name':"
    printf ' - %s\n' "${installed_now[@]}"
  else
    warn "Nenhum novo pacote foi instalado em '$module_name'."
  fi

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

try_launch_steam_for_normal_user() {
  if [ "$INSTALL_GAMING" = false ] || [ "$DRY_RUN" = true ]; then
    return
  fi

  if ! package_installed "steam-installer"; then
    return
  fi

  local target_user=""
  if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
    target_user="$SUDO_USER"
  elif [ "$EUID" -ne 0 ]; then
    target_user="$USER"
  elif [ -n "${LOGNAME:-}" ] && [ "${LOGNAME}" != "root" ]; then
    target_user="$LOGNAME"
  elif command -v logname >/dev/null 2>&1; then
    target_user="$(logname 2>/dev/null || true)"
    if [ "$target_user" = "root" ]; then
      target_user=""
    fi
  fi

  if [ -z "$target_user" ] && [ -n "${PKEXEC_UID:-}" ]; then
    target_user="$(id -nu "$PKEXEC_UID" 2>/dev/null || true)"
  fi

  if [ -z "$target_user" ] && [ "$EUID" -eq 0 ]; then
    target_user="$(
      awk -F: '$3 >= 1000 && $1 != "nobody" && $7 !~ /(nologin|false)/ { print $1; exit }' /etc/passwd
    )"
  fi

  if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    warn "Steam instalado. Execute como usuário normal para baixar o cliente:"
    warn "  su - <usuario> -c steam"
    return
  fi

  if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    warn "Steam instalado. Abra pelo menu da sessão gráfica do usuário '$target_user' para concluir o download inicial."
    return
  fi

  local uid runtime_dir
  uid="$(id -u "$target_user" 2>/dev/null || true)"
  runtime_dir="/run/user/$uid"

  log "Tentando iniciar Steam automaticamente no usuário '$target_user'..."
  if [ "$EUID" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
    runuser -u "$target_user" -- env \
      DISPLAY="${DISPLAY:-}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      XDG_RUNTIME_DIR="$runtime_dir" \
      steam >/dev/null 2>&1 &
    success "Steam iniciado para '$target_user'."
    return
  fi

  if [ "$EUID" -eq 0 ] && command -v su >/dev/null 2>&1; then
    su - "$target_user" -c "DISPLAY='${DISPLAY:-}' WAYLAND_DISPLAY='${WAYLAND_DISPLAY:-}' XDG_RUNTIME_DIR='$runtime_dir' steam" \
      >/dev/null 2>&1 &
    success "Steam iniciado para '$target_user'."
    return
  fi

  if [ "$EUID" -eq 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo -u "$target_user" -H env \
      DISPLAY="${DISPLAY:-}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      XDG_RUNTIME_DIR="$runtime_dir" \
      steam >/dev/null 2>&1 &
    success "Steam iniciado para '$target_user'."
    return
  fi

  if [ "$EUID" -ne 0 ]; then
    env \
      DISPLAY="${DISPLAY:-}" \
      WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      steam >/dev/null 2>&1 &
    success "Steam iniciado para '$target_user'."
    return
  fi

  warn "Steam instalado, mas não foi possível iniciar automaticamente."
  warn "Execute manualmente com: su - $target_user -c steam"
}
