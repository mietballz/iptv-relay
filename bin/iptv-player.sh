#!/usr/bin/env bash
# ---------------------------------------------------------------
# iptv-player.sh – startet ffplay mit den Werten aus der Konfiguration
# Wird vom systemd User-Service iptv-relay.service aufgerufen.
# ---------------------------------------------------------------
set -euo pipefail

CONFIG_FILE="${IPTV_CONFIG:-${HOME}/.config/iptv-relay/iptv-relay.env}"

if [[ ! -r "$CONFIG_FILE" ]]; then
  echo "FEHLER: Konfiguration nicht gefunden: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${STREAM_URL:?STREAM_URL ist nicht gesetzt}"

if [[ "$STREAM_URL" == *"x.x.x"* ]]; then
  echo "FEHLER: STREAM_URL enthält noch den Platzhalter – bitte in $CONFIG_FILE anpassen." >&2
  exit 1
fi

exec /usr/bin/ffplay \
  -hide_banner \
  -loglevel warning \
  -i "$STREAM_URL" \
  -fs \
  -window_title "${WINDOW_TITLE:-IPTV}" \
  -volume "${FFPLAY_VOLUME:-100}" \
  -af "volume=${AUDIO_GAIN:-2}"
