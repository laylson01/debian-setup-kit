#!/usr/bin/env bash
# shellcheck disable=SC2034

if [ "$EUID" -eq 0 ]; then
  APT_CMD=(apt-get)
else
  APT_CMD=(sudo apt-get)
fi

export DEBIAN_FRONTEND=noninteractive

INSTALLED_THIS_RUN=()

INSTALL_BASE=false
INSTALL_TERMINAL=false
INSTALL_DEV=false
INSTALL_NETWORK=false
INSTALL_AUTOMATION=false
INSTALL_EMBEDDED=false
INSTALL_OPTIONAL=false
DO_UPDATE=true
DO_UPGRADE=true
DRY_RUN=false
ASSUME_YES=false
ROLLBACK_SOURCES=false
AUTO_FIX_APT_MODE="off"
INTERACTIVE=false
INTERACTIVE_MODE="auto"
PROFILE="none"
