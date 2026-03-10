#!/usr/bin/env bash
# shellcheck disable=SC2034

if [ "$EUID" -eq 0 ]; then
  APT_CMD=(apt-get)
else
  APT_CMD=(sudo apt-get)
fi

export DEBIAN_FRONTEND=noninteractive

INSTALLED_THIS_RUN=()

# Seleção de stacks: controla apenas instalação de pacotes por domínio.
INSTALL_BASE=false
INSTALL_TERMINAL=false
INSTALL_DEV=false
INSTALL_NETWORK=false
INSTALL_AUTOMATION=false
INSTALL_EMBEDDED=false
INSTALL_GAMING=false
INSTALL_OPTIONAL=false
INSTALL_DESKTOP_BASIC=false
INSTALL_DESKTOP_FULL=false

# Fluxo principal do APT.
DO_UPDATE=true
DO_UPGRADE=true
DRY_RUN=false
ASSUME_YES=false
ROLLBACK_SOURCES=false
AUTO_FIX_APT_MODE="off"

# Modos de interação e listagem.
INTERACTIVE=false
INTERACTIVE_MODE="auto"
PROFILE="none"
LIST_PACKAGES=false

# Ações sensíveis exigem opt-in explícito para manter o default conservador.
ENABLE_I386=false
ENABLE_SERVICES=false
CREATE_USER_DIRS=false

# Sinaliza que uma ação prévia exige apt update antes das instalações.
NEEDS_APT_UPDATE_AFTER_ARCH_ADD=false
