FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# 1. Core desktop (Xvfb, Fluxbox, x11vnc, noVNC), Password Manager (D-Bus, gnome-keyring),
#    PulseAudio virtual audio, GL/Mesa, and realistic Linux desktop fonts
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Display & VNC / noVNC
    xvfb \
    fluxbox \
    pcmanfm \
    x11vnc \
    novnc \
    websockify \
    x11-utils \
    x11-xserver-utils \
    xdotool \
    xclip \
    wmctrl \
    # Password Manager / Secret Service
    dbus \
    dbus-x11 \
    gnome-keyring \
    libsecret-1-0 \
    libsecret-tools \
    seahorse \
    # Audio (realistic Web Audio / AudioContext fingerprint)
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    # Graphics / Mesa / XDG
    libgl1 \
    libglx-mesa0 \
    libegl1 \
    libgbm1 \
    mesa-utils \
    xdg-utils \
    # Realistic Linux desktop font pack
    fontconfig \
    fonts-ubuntu \
    fonts-liberation \
    fonts-dejavu-core \
    fonts-noto-core \
    fonts-noto-color-emoji \
    # Utilities & Locales
    ca-certificates \
    curl \
    gnupg \
    locales \
    procps \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && dbus-uuidgen > /etc/machine-id \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

# 2. Install official Google Chrome Stable natively for the container architecture (arm64 or amd64)
RUN ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && echo "Installing official Google Chrome Stable for ${ARCH}..." \
    && curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_${ARCH}.deb" -o /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/google-chrome.deb \
    && rm -f /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

# 3. Make noVNC open directly into vnc.html at http://localhost:6080/
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 4. Install helper scripts for desktop, keyring, and headed Chrome
COPY scripts/start-desktop.sh /usr/local/bin/start-desktop.sh
COPY scripts/launch-chrome.sh /usr/local/bin/launch-chrome
RUN chmod +x /usr/local/bin/start-desktop.sh /usr/local/bin/launch-chrome

# 5. Add a Fluxbox menu entry for launching Chrome from the desktop
RUN mkdir -p /home/vscode/.fluxbox \
    && printf '%s\n' \
      '[begin] (Dev Container)' \
      '  [exec] (Google Chrome) {/usr/local/bin/launch-chrome}' \
      '  [exec] (Passwords & Keys - Seahorse) {seahorse}' \
      '  [exec] (Terminal) {x-terminal-emulator}' \
      '  [reconfig] (Reconfigure)' \
      '  [restart] (Restart)' \
      '[end]' \
      > /home/vscode/.fluxbox/menu \
    && mkdir -p /home/vscode/Desktop \
    && printf '%s\n' \
      '[Desktop Entry]' \
      'Version=1.0' \
      'Type=Application' \
      'Name=Google Chrome' \
      'Comment=Access the Internet' \
      'Exec=/usr/local/bin/launch-chrome' \
      'Icon=google-chrome' \
      'Terminal=false' \
      'Categories=Network;WebBrowser;' \
      > /home/vscode/Desktop/google-chrome.desktop \
    && chmod +x /home/vscode/Desktop/google-chrome.desktop \
    && chown -R vscode:vscode /home/vscode/.fluxbox /home/vscode/Desktop

USER vscode
