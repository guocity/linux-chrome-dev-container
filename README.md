# Ubuntu 24.04 + Google Chrome Dev Container

A graphical Ubuntu 24.04 development container with Google Chrome Stable and
Node.js 24. It runs Chrome with a virtual desktop, so it can be used headlessly
or viewed through a browser-based desktop.

## Container image

Pull the published image:

```sh
docker pull ghcr.io/guocity/ubuntu-24.04-google-chrome:02ce92fb94380bc754ad696598e753d257683a8a
```

The Dev Container configuration in this repository builds from
`.devcontainer/Dockerfile` and adds the Node.js 24 feature. The published image
is built for both `linux/amd64` and `linux/arm64`.

## What's installed

- Ubuntu 24.04 base and Google Chrome Stable.
- Node.js 24.
- Xvfb and Fluxbox for a virtual display and window manager.
- x11vnc and noVNC for remote desktop access.
- D-Bus and GNOME Keyring for Chrome's password manager.
- PulseAudio with a virtual audio output.
- Mesa/GL libraries, desktop utilities, and Ubuntu, Liberation, DejaVu, Noto,
  and emoji fonts.
- `en_US.UTF-8` locale and common utilities such as `curl`, `gnupg`, and `procps`.

## Chrome profile and saved data

Chrome's user data directory is `${containerWorkspaceFolder}/.chrome-profile`
(the `.chrome-profile` directory in the workspace root). It holds Chrome
settings, cookies, browsing data, and other profile state, so it persists when
the Dev Container is rebuilt as long as the workspace files are retained.

GNOME Keyring data is stored in `.chrome-profile/.keyrings`. At startup,
`start-desktop.sh` links this directory to
`~/.local/share/keyrings` inside the container. This keeps Chrome Password
Manager data with the profile. A default keyring is initialized on first start.

The profile directory is git-ignored. It can contain sensitive data, including
signed-in sessions and saved passwords; do not commit it or share it
unintentionally. Back it up only to a trusted location.

## Desktop and Chrome startup

The Dev Container starts the virtual desktop and launches Chrome in the
background when it starts. To open the desktop, visit **http://localhost:6080**
in your browser (noVNC). VNC is exposed on port `5901`.

Chrome's remote debugging (CDP) endpoint is forwarded on port `9222` and bound
to `127.0.0.1` inside the container. The container also forwards port `3000`
for an application server. Chrome uses the persisted `.chrome-profile` and
`--password-store=gnome-libsecret`.

VNC and noVNC are configured without a password. Keep the desktop ports
accessible only from trusted machines.
