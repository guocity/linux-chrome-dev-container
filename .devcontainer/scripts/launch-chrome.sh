#!/usr/bin/env bash
set -euo pipefail

BACKGROUND=false
EXTRA_ARGS=()

for arg in "$@"; do
  if [ "$arg" = "--background" ]; then
    BACKGROUND=true
  else
    EXTRA_ARGS+=("$arg")
  fi
done

export DISPLAY="${DISPLAY:-:1}"
CHROME_PROFILE_DIR="${CHROME_PROFILE_DIR:-${PWD}/.chrome-profile}"
CHROME_DEBUG_PORT="${CHROME_DEBUG_PORT:-9222}"

# Ensure desktop, D-Bus, and gnome-keyring are running
/usr/local/bin/start-desktop.sh >/dev/null

# Load D-Bus & gnome-keyring environment so Chrome connects to the persisted keyring
if [ -f /tmp/chrome-session.env ]; then
  # shellcheck disable=SC1091
  source /tmp/chrome-session.env
fi

mkdir -p "${CHROME_PROFILE_DIR}"

# Clean stale Singleton locks left behind if a previous container stopped abruptly
if ! pgrep -f "/opt/google/chrome/chrome.*--user-data-dir=${CHROME_PROFILE_DIR}" >/dev/null 2>&1; then
  rm -f \
    "${CHROME_PROFILE_DIR}/SingletonLock" \
    "${CHROME_PROFILE_DIR}/SingletonSocket" \
    "${CHROME_PROFILE_DIR}/SingletonCookie"
fi

CHROME_FLAGS=(
  "--user-data-dir=${CHROME_PROFILE_DIR}"
  "--password-store=gnome-libsecret"
  "--remote-debugging-port=${CHROME_DEBUG_PORT}"
  "--remote-debugging-address=127.0.0.1"
  "--no-first-run"
  "--no-default-browser-check"
  "--start-maximized"
)

if [ -n "${CHROME_USER_AGENT:-}" ]; then
  CHROME_FLAGS+=("--user-agent=${CHROME_USER_AGENT}")
fi

if [ "${BACKGROUND}" = true ]; then
  if pgrep -f "/opt/google/chrome/chrome.*--user-data-dir=${CHROME_PROFILE_DIR}" >/dev/null 2>&1; then
    echo "Google Chrome is already running (profile: ${CHROME_PROFILE_DIR})."
    exit 0
  fi
  setsid -f /usr/bin/google-chrome-stable "${CHROME_FLAGS[@]}" "${EXTRA_ARGS[@]}" </dev/null >/tmp/chrome.log 2>&1
  echo "Google Chrome started in background (profile: ${CHROME_PROFILE_DIR}, CDP: http://localhost:${CHROME_DEBUG_PORT})."
else
  exec /usr/bin/google-chrome-stable "${CHROME_FLAGS[@]}" "${EXTRA_ARGS[@]}"
fi
