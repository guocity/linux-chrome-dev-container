#!/usr/bin/env bash
set -euo pipefail

export DISPLAY="${DISPLAY:-:1}"
SCREEN_WIDTH="${SCREEN_WIDTH:-1920}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-1080}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
CHROME_PROFILE_DIR="${CHROME_PROFILE_DIR:-${PWD}/.chrome-profile}"
ENV_FILE="/tmp/chrome-session.env"

mkdir -p "${CHROME_PROFILE_DIR}/.keyrings"
mkdir -p "${HOME}/.local/share"

# Persist GNOME Keyring inside the project root (.chrome-profile/.keyrings)
# so Chrome Password Manager entries survive container rebuilds.
KEYRING_LINK="${HOME}/.local/share/keyrings"
if [ -L "${KEYRING_LINK}" ]; then
  rm -f "${KEYRING_LINK}"
elif [ -d "${KEYRING_LINK}" ]; then
  cp -rn "${KEYRING_LINK}/." "${CHROME_PROFILE_DIR}/.keyrings/" 2>/dev/null || true
  rm -rf "${KEYRING_LINK}"
fi
ln -s "${CHROME_PROFILE_DIR}/.keyrings" "${KEYRING_LINK}"

# Ensure a passwordless default keyring exists on first boot so Chrome never blocks on an unlock popup
if [ ! -f "${CHROME_PROFILE_DIR}/.keyrings/default" ] && [ ! -f "${CHROME_PROFILE_DIR}/.keyrings/Default_keyring.keyring" ]; then
  printf 'Default_keyring\n' > "${CHROME_PROFILE_DIR}/.keyrings/default"
  cat > "${CHROME_PROFILE_DIR}/.keyrings/Default_keyring.keyring" <<'EOF'
[keyring]
display-name=Default keyring
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
EOF
  chmod 700 "${CHROME_PROFILE_DIR}/.keyrings"
  chmod 600 "${CHROME_PROFILE_DIR}/.keyrings/Default_keyring.keyring"
fi

# 1. Start Xvfb (virtual framebuffer with realistic desktop resolution)
if ! pgrep -x Xvfb >/dev/null 2>&1; then
  rm -f "/tmp/.X${DISPLAY#:}-lock" "/tmp/.X11-unix/X${DISPLAY#:}"
  setsid -f Xvfb "${DISPLAY}" -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" -ac +extension GLX +render -noreset </dev/null >/tmp/xvfb.log 2>&1
  for _ in $(seq 1 30); do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

# 2. Start D-Bus session + gnome-keyring-daemon for Chrome Password Manager
if [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}" || true
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || ! pgrep -x dbus-daemon >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  {
    echo "export DBUS_SESSION_BUS_ADDRESS='${DBUS_SESSION_BUS_ADDRESS}'"
    echo "export DBUS_SESSION_BUS_PID='${DBUS_SESSION_BUS_PID}'"
  } > "${ENV_FILE}"
fi

if ! pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
  eval "$(printf '%s\n' "${KEYRING_PASSWORD:-}" | gnome-keyring-daemon --unlock --start --components=pkcs11,secrets 2>/dev/null || gnome-keyring-daemon --start --components=pkcs11,secrets)"
  {
    [ -n "${GNOME_KEYRING_CONTROL:-}" ] && echo "export GNOME_KEYRING_CONTROL='${GNOME_KEYRING_CONTROL}'"
    [ -n "${SSH_AUTH_SOCK:-}" ] && echo "export SSH_AUTH_SOCK='${SSH_AUTH_SOCK}'"
  } >> "${ENV_FILE}"
fi

# 3. Start PulseAudio with a dummy sink (realistic Web Audio API / AudioContext)
if ! pulseaudio --check >/dev/null 2>&1; then
  pulseaudio --start --exit-idle-time=-1 >/tmp/pulseaudio.log 2>&1 || true
  pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=Virtual_Speaker >/dev/null 2>&1 || true
fi

# 4. Start Fluxbox window manager
if ! pgrep -x fluxbox >/dev/null 2>&1; then
  setsid -f fluxbox </dev/null >/tmp/fluxbox.log 2>&1
  sleep 0.5
fi

# 4b. Start PCManFM desktop manager for desktop icons (e.g. Google Chrome)
if ! pgrep -f "pcmanfm --desktop" >/dev/null 2>&1; then
  setsid -f pcmanfm --desktop </dev/null >/tmp/pcmanfm.log 2>&1
  sleep 0.3
fi

# 5. Start x11vnc (setsid detaches from parent session so SIGHUP cannot kill it)
if ! pgrep -x x11vnc >/dev/null 2>&1; then
  setsid -f x11vnc -display "${DISPLAY}" -rfbport "${VNC_PORT}" -forever -shared -nopw -xkb -ncache 0 </dev/null >/tmp/x11vnc.log 2>&1
  for _ in $(seq 1 30); do
    if bash -c "exec 3<>/dev/tcp/127.0.0.1/${VNC_PORT}" 2>/dev/null; then
      break
    fi
    sleep 0.2
  done
fi

# 6. Start noVNC (browser-accessible desktop at http://localhost:6080)
if ! pgrep -f "websockify.*${NOVNC_PORT}" >/dev/null 2>&1; then
  setsid -f websockify --web=/usr/share/novnc/ "${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" </dev/null >/tmp/novnc.log 2>&1
fi

echo "Desktop ready: http://localhost:${NOVNC_PORT} (VNC: localhost:${VNC_PORT})"
