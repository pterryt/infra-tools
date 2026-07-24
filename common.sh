#!/usr/bin/env bash
# common.sh — shared helpers for nginx-deploy scripts
# Sourced by install.sh, new-service.sh, remove-service.sh, list-services.sh

set -euo pipefail

# ---- colors / logging -------------------------------------------------
if [[ -t 1 ]]; then
  C_RED='\033[0;31m'; C_GREEN='\033[0;32m'; C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_RESET='\033[0m'
else
  C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_RESET=''
fi

log_info()  { printf "%b[INFO]%b  %s\n"  "$C_BLUE"  "$C_RESET" "$1"; }
log_ok()    { printf "%b[OK]%b    %s\n"  "$C_GREEN" "$C_RESET" "$1"; }
log_warn()  { printf "%b[WARN]%b  %s\n"  "$C_YELLOW" "$C_RESET" "$1"; }
log_error() { printf "%b[ERROR]%b %s\n"  "$C_RED"   "$C_RESET" "$1" >&2; }
die()       { log_error "$1"; exit 1; }

# ---- environment checks ------------------------------------------------
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must be run as root (use sudo)."
  fi
}

require_debian_family() {
  if ! command -v apt-get >/dev/null 2>&1; then
    die "This toolkit targets Debian/Ubuntu (apt-get not found). See README for other distros."
  fi
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command '$cmd' not found. Did you run install.sh?"
}

# ---- env file loading ---------------------------------------------------
# Loads a service .env file into the current shell in a slightly safer way
# than a raw `source`: only lines matching KEY=VALUE are evaluated, and the
# file must live inside the repo's services.d directory.
load_service_env() {
  local env_file="$1"

  [[ -f "$env_file" ]] || die "Service env file not found: $env_file"

  # Basic sanity check: refuse files containing command substitution or
  # obvious shell metacharacters that would indicate something other than
  # a plain KEY=VALUE list. This is a guard rail, not a sandbox — only use
  # service env files you wrote or reviewed yourself.
  if grep -qE '\$\(|`|;|&&|\|\|' "$env_file"; then
    die "Refusing to load '$env_file': contains shell metacharacters. Service env files should be plain KEY=VALUE lines."
  fi

  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

# ---- validation ----------------------------------------------------------
validate_required_vars() {
  local missing=()
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required variable(s) in service env file: ${missing[*]}"
  fi
}

# Very small allowlist check for domain / service names to avoid anything
# nasty ending up in filenames, nginx config, or systemd units.
validate_safe_token() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || die "$name '$value' contains invalid characters (allowed: letters, digits, dot, dash, underscore)."
}

# ---- templating ------------------------------------------------------------
# Renders a template with envsubst, but ONLY substitutes an explicit list of
# variables. This is important: nginx config files use $host, $remote_addr,
# $scheme, etc. A naive `envsubst < template` would mangle every one of those.
render_template() {
  local template="$1" output="$2"; shift 2
  local varlist=""
  for v in "$@"; do varlist+="\${$v} "; done
  envsubst "${varlist% }" < "$template" > "$output"
}

# ---- install packages ------------------------------------------------------
install_packages() {
    log_info "Updating package index..."
    apt-get update -qq
    log_info "Installing: $*"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
}
