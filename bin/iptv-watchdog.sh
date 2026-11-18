#!/usr/bin/env bash
# ---------------------------------------------------------------
# iptv-watchdog.sh – Selbstheilung für das IPTV-Relay
#
# Prüft (per Cron alle 5 Minuten):
#   1. Netzwerk: Interface UP, IPv4 vorhanden, Gateway erreichbar
#   2. systemd User-Service aktiv
#   3. ffplay-Prozess läuft
# Bei Fehlern wird das Netzwerk neu angewendet bzw. der Service neu gestartet.
# ---------------------------------------------------------------
set -uo pipefail

CONFIG_FILE="${IPTV_CONFIG:-${HOME}/.config/iptv-relay/iptv-relay.env}"
# shellcheck source=/dev/null
[[ -r "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

SERVICE_NAME="${SERVICE_NAME:-iptv-relay.service}"
INTERFACES="${INTERFACES:-enp1s0 eth0 wlan0}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"
LOG_DIR="${LOG_DIR:-${HOME}/.local/state/iptv-relay}"
LOG_FILE="${LOG_DIR}/watchdog.log"

mkdir -p "$LOG_DIR"

# Cron startet ohne Session-Umgebung. Ohne diese Variablen
# kann "systemctl --user" den User-Manager nicht erreichen.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"; }

# Erstes Interface im Zustand UP (Reihenfolge = Priorität)
find_active_interface() {
  local iface
  for iface in $INTERFACES; do
    if ip link show "$iface" 2>/dev/null | grep -q 'state UP'; then
      echo "$iface"
      return 0
    fi
  done
  return 1
}

find_gateway() {
  ip route show default 2>/dev/null | awk '{print $3; exit}'
}

get_ip() {
  ip -4 -o addr show "$1" 2>/dev/null | awk '{print $4; exit}' | cut -d/ -f1
}

check_network() {
  local iface="$1" gw="$2"
  [[ -n "$iface" && -n "$gw" ]]            || return 1
  ip link show "$iface" | grep -q 'state UP' || return 1
  ip addr show "$iface" | grep -q 'inet '    || return 1
  ping -c 1 -W 3 "$gw" &>/dev/null           || return 1
}

reconnect_network() {
  log 'WARN: Netzwerkproblem erkannt – wende Netplan erneut an'
  # Benötigt einen sudoers-Eintrag (siehe docs/installation.md)
  if sudo -n /usr/sbin/netplan apply 2>>"$LOG_FILE"; then
    log 'INFO: netplan apply ausgeführt'
  else
    log 'ERROR: netplan apply fehlgeschlagen (sudo-Rechte prüfen)'
  fi
  sleep 10
}

check_service() {
  if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    log "OK: Service $SERVICE_NAME läuft"
  else
    log "WARN: Service $SERVICE_NAME nicht aktiv – starte neu"
    systemctl --user restart "$SERVICE_NAME"
  fi
}

check_ffplay() {
  local pid
  if pid=$(pgrep -x ffplay | head -1) && [[ -n "$pid" ]]; then
    log "OK: ffplay läuft (PID: $pid)"
  else
    log 'WARN: ffplay nicht gefunden – starte Service neu'
    systemctl --user restart "$SERVICE_NAME"
  fi
}

# --- Hauptprogramm ---------------------------------------------
log '=================================================='
log 'INFO: Watchdog gestartet'

network_ok=false
for (( i = 1; i <= MAX_RETRIES; i++ )); do
  IFACE=$(find_active_interface || true)
  GW=$(find_gateway)
  if check_network "$IFACE" "$GW"; then
    log "OK: Netzwerk aktiv (Interface: $IFACE, IP: $(get_ip "$IFACE"), Gateway: $GW)"
    network_ok=true
    break
  fi
  log "WARN: Netzwerkprüfung $i/$MAX_RETRIES fehlgeschlagen (Interface: ${IFACE:-keins}, Gateway: ${GW:-keins})"
  sleep "$RETRY_DELAY"
done

[[ "$network_ok" == true ]] || reconnect_network

check_service
check_ffplay

log 'INFO: Watchdog beendet'
log '=================================================='
