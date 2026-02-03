#!/usr/bin/env bash
# Shared config and helpers for toku-agent scripts
# Source this at the top of every script: source "$(dirname "$0")/_common.sh"

set -euo pipefail

TOKU_BASE="https://www.toku.agency/api"
TOKU_CONFIG_DIR="${HOME}/.config/toku"
TOKU_KEY_FILE="${TOKU_CONFIG_DIR}/api_key"

# Get API key from env or file
get_api_key() {
  if [ -n "${TOKU_API_KEY:-}" ]; then
    echo "$TOKU_API_KEY"
    return
  fi
  if [ -f "$TOKU_KEY_FILE" ]; then
    cat "$TOKU_KEY_FILE"
    return
  fi
  echo "ERROR: No API key found. Set TOKU_API_KEY or run register.sh first." >&2
  exit 1
}

# Save API key to config file
save_api_key() {
  local key="$1"
  mkdir -p "$TOKU_CONFIG_DIR"
  echo "$key" > "$TOKU_KEY_FILE"
  chmod 600 "$TOKU_KEY_FILE"
}

# Authenticated GET request
toku_get() {
  local path="$1"
  shift
  curl -sf --max-time 30 "${TOKU_BASE}${path}" \
    -H "Authorization: Bearer $(get_api_key)" \
    "$@" 2>/dev/null
}

# Authenticated POST request
toku_post() {
  local path="$1"
  local data="$2"
  shift 2
  curl -sf --max-time 30 -X POST "${TOKU_BASE}${path}" \
    -H "Authorization: Bearer $(get_api_key)" \
    -H "Content-Type: application/json" \
    -d "$data" \
    "$@" 2>/dev/null
}

# Authenticated PATCH request
toku_patch() {
  local path="$1"
  local data="$2"
  shift 2
  curl -sf --max-time 30 -X PATCH "${TOKU_BASE}${path}" \
    -H "Authorization: Bearer $(get_api_key)" \
    -H "Content-Type: application/json" \
    -d "$data" \
    "$@" 2>/dev/null
}

# Unauthenticated POST request (for registration)
toku_post_noauth() {
  local path="$1"
  local data="$2"
  shift 2
  curl -sf --max-time 30 -X POST "${TOKU_BASE}${path}" \
    -H "Content-Type: application/json" \
    -d "$data" \
    "$@" 2>/dev/null
}
