#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/apt.sh
source "$PROJECT_ROOT/lib/apt.sh"

TEST_OUTPUT=""
MOCK_APT_POLICY=""
MOCK_SYSTEM_CODENAME=""

apt-cache() {
  if [ "${1:-}" = "policy" ]; then
    printf '%s\n' "$MOCK_APT_POLICY"
    return 0
  fi

  command apt-cache "$@"
}

get_system_codename() {
  printf '%s\n' "$MOCK_SYSTEM_CODENAME"
}

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

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'Expected output to contain: %s\n' "$needle" >&2
    printf 'Actual output:\n%s' "$haystack" >&2
    exit 1
  fi
}

run_case() {
  local name="$1"

  TEST_OUTPUT=""
  if ! ensure_apt_release_consistency; then
    printf 'Test failed: %s\n%s' "$name" "$TEST_OUTPUT" >&2
    exit 1
  fi
}

AUTO_FIX_APT_MODE="off"
DRY_RUN=false
APT_CMD=(apt-get)

MOCK_SYSTEM_CODENAME="trixie"
MOCK_APT_POLICY=$'500 http://deb.debian.org/debian trixie/main amd64 Packages\n     release v=13.0,o=Debian,a=stable,n=trixie,l=Debian,c=main,b=amd64\n500 http://deb.debian.org/debian bookworm/main amd64 Packages\n     release v=12.0,o=Debian,a=oldstable,n=bookworm,l=Debian,c=main,b=amd64'
run_case "multiple primary codenames only warns"
assert_contains "$TEST_OUTPUT" "WARN: Foram detectados múltiplos codenames Debian nos repositórios APT:"
assert_contains "$TEST_OUTPUT" "WARN: A execução continuará."

MOCK_SYSTEM_CODENAME="trixie"
MOCK_APT_POLICY=$'500 http://deb.debian.org/debian bookworm/main amd64 Packages\n     release v=12.0,o=Debian,a=oldstable,n=bookworm,l=Debian,c=main,b=amd64'
run_case "mismatched system codename only warns"
assert_contains "$TEST_OUTPUT" "WARN: Codename do sistema: trixie"
assert_contains "$TEST_OUTPUT" "WARN: Sistema e repositórios estão desalinhados; isso causa conflitos de dependência."

MOCK_SYSTEM_CODENAME="trixie"
MOCK_APT_POLICY=$'500 http://deb.debian.org/debian trixie/main amd64 Packages\n     release v=13.0,o=Debian,a=stable,n=trixie,l=Debian,c=main,b=amd64\n500 http://deb.debian.org/debian bookworm-backports/main amd64 Packages\n     release o=Debian Backports,a=oldstable-backports,n=bookworm-backports,l=Debian Backports,c=main,b=amd64'
run_case "foreign backports are allowed with warning"
assert_contains "$TEST_OUTPUT" "WARN: Backports de outra release detectados; mantendo como exceção permitida:"

printf 'apt_release_consistency_test: ok\n'
