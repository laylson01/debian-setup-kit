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
