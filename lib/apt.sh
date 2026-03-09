#!/usr/bin/env bash

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

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}
