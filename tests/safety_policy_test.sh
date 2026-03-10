#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/defaults.sh
source "$PROJECT_ROOT/lib/defaults.sh"
# shellcheck source=lib/apt.sh
source "$PROJECT_ROOT/lib/apt.sh"
# shellcheck source=lib/install.sh
source "$PROJECT_ROOT/lib/install.sh"

TEST_OUTPUT=""
DPKG_CALLED=false
AS_ROOT_CALLS=0
CREATE_DIRS_CALLS=0
ENABLE_SSH_CALLS=0

warn() {
  TEST_OUTPUT+="WARN: $1"$'\n'
}

error() {
  TEST_OUTPUT+="ERROR: $1"$'\n'
}

success() {
  TEST_OUTPUT+="SUCCESS: $1"$'\n'
}

log() {
  :
}

dpkg() {
  DPKG_CALLED=true

  if [ "${1:-}" = "--print-foreign-architectures" ]; then
    return 0
  fi

  printf 'unexpected dpkg call: %s\n' "$*" >&2
  exit 1
}

as_root() {
  AS_ROOT_CALLS=$((AS_ROOT_CALLS + 1))
}

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s' "$haystack" >&2
    exit 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"

  if [ "$expected" != "$actual" ]; then
    printf 'Expected "%s", got "%s"\n' "$expected" "$actual" >&2
    exit 1
  fi
}

reset_state() {
  TEST_OUTPUT=""
  DPKG_CALLED=false
  AS_ROOT_CALLS=0
  CREATE_DIRS_CALLS=0
  ENABLE_SSH_CALLS=0
  INSTALL_GAMING=false
  ENABLE_I386=false
  ENABLE_SERVICES=false
  CREATE_USER_DIRS=false
  DRY_RUN=false
  NEEDS_APT_UPDATE_AFTER_ARCH_ADD=false
}

reset_state
INSTALL_GAMING=true
ensure_gaming_prereqs
assert_contains "$TEST_OUTPUT" "WARN: As stacks gaming/embedded podem precisar de i386 para pacotes e bibliotecas 32-bit."
assert_equals "false" "$DPKG_CALLED"
assert_equals "false" "$NEEDS_APT_UPDATE_AFTER_ARCH_ADD"

reset_state
INSTALL_GAMING=true
ENABLE_I386=true
ensure_gaming_prereqs
assert_equals "1" "$AS_ROOT_CALLS"
assert_equals "true" "$NEEDS_APT_UPDATE_AFTER_ARCH_ADD"

reset_state
INSTALL_EMBEDDED=true
ENABLE_I386=true
ensure_gaming_prereqs
assert_equals "1" "$AS_ROOT_CALLS"
assert_equals "true" "$NEEDS_APT_UPDATE_AFTER_ARCH_ADD"

create_directories() {
  CREATE_DIRS_CALLS=$((CREATE_DIRS_CALLS + 1))
}

enable_ssh_if_installed() {
  ENABLE_SSH_CALLS=$((ENABLE_SSH_CALLS + 1))
}

reset_state
apply_post_install_actions
assert_contains "$TEST_OUTPUT" "WARN: Criação de diretórios do usuário desabilitada."
assert_contains "$TEST_OUTPUT" "WARN: Habilitação automática de serviços desabilitada."
assert_equals "0" "$CREATE_DIRS_CALLS"
assert_equals "0" "$ENABLE_SSH_CALLS"

reset_state
CREATE_USER_DIRS=true
ENABLE_SERVICES=true
apply_post_install_actions
assert_equals "1" "$CREATE_DIRS_CALLS"
assert_equals "1" "$ENABLE_SSH_CALLS"

printf 'safety_policy_test: ok\n'
