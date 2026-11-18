#!/usr/bin/env bash
# ---------------------------------------------------------------
# install.sh – installiert das IPTV-Relay für den aktuellen Benutzer
#
# Aufruf als Kiosk-Benutzer (NICHT als root):
#   ./install.sh
#
# Systemweite Schritte (Autologin, Netplan, Reboot-Cron, sudoers)
# werden NICHT automatisch ausgeführt – siehe docs/installation.md.
# ---------------------------------------------------------------
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Bitte als Kiosk-Benutzer ausführen, nicht als root." >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONF_DIR="${HOME}/.config/iptv-relay"
UNIT_DIR="${HOME}/.config/systemd/user"
STATE_DIR="${HOME}/.local/state/iptv-relay"

echo "==> Abhängigkeiten prüfen"
missing=()
for cmd in ffplay ffprobe pactl ip ping pgrep crontab; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if (( ${#missing[@]} )); then
  echo "Fehlend: ${missing[*]}"
  echo "Installieren mit: sudo apt install ffmpeg pulseaudio-utils iproute2 iputils-ping procps cron"
  exit 1
fi

echo "==> Verzeichnisse anlegen"
mkdir -p "$BIN_DIR" "$CONF_DIR" "$UNIT_DIR" "$STATE_DIR"

echo "==> Skripte installieren"
install -m 755 "$REPO_DIR/bin/iptv-player.sh"   "$BIN_DIR/"
install -m 755 "$REPO_DIR/bin/iptv-watchdog.sh" "$BIN_DIR/"

echo "==> Konfiguration"
if [[ -f "$CONF_DIR/iptv-relay.env" ]]; then
  echo "    $CONF_DIR/iptv-relay.env existiert bereits – wird nicht überschrieben."
else
  install -m 640 "$REPO_DIR/config/iptv-relay.env.example" "$CONF_DIR/iptv-relay.env"
  echo "    Vorlage kopiert – STREAM_URL in $CONF_DIR/iptv-relay.env anpassen!"
fi

echo "==> systemd User-Units installieren"
install -m 644 "$REPO_DIR"/systemd/user/* "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable iptv-relay.service iptv-relay-restart.timer

echo "==> Watchdog-Cronjob eintragen"
CRON_LINE="*/5 * * * * \$HOME/.local/bin/iptv-watchdog.sh"
( crontab -l 2>/dev/null | grep -v 'iptv-watchdog.sh' ; echo "$CRON_LINE" ) | crontab -

cat <<EOF

Fertig. Nächste Schritte:
  1. STREAM_URL setzen:      nano $CONF_DIR/iptv-relay.env
  2. Linger aktivieren:      sudo loginctl enable-linger $USER
  3. Service starten:        systemctl --user start iptv-relay.service
  4. Systemweite Schritte:   siehe docs/installation.md
EOF
