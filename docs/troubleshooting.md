# Troubleshooting

## Fehlermatrix

| Symptom | Mögliche Ursache | Diagnose | Lösung |
|---|---|---|---|
| Kein Bild | ffplay läuft nicht / kein Multicast | `systemctl --user status iptv-relay` | `systemctl --user restart iptv-relay` |
| Kein Ton | Falscher PulseAudio-Sink | `pactl info \| grep Default` | `pactl set-default-sink <HDMI_SINK>` |
| Service startet nicht | PulseAudio noch nicht bereit / Config fehlt | `journalctl --user -u iptv-relay` | `After=pulseaudio.service`, Config prüfen |
| Neustart-Schleife | Multicast-Ausfall / IGMP | `ffprobe udp://@224.x.x.x:5000` | Netzwerk / Switch (IGMP Snooping) prüfen |
| Watchdog läuft nicht | Cron fehlt / nicht ausführbar | `crontab -l` | `chmod +x ~/.local/bin/iptv-watchdog.sh` |
| Watchdog kann Service nicht neu starten | Keine User-Bus-Umgebung | `watchdog.log` | Linger aktivieren |
| Timer läuft nicht | Linger fehlt | `systemctl --user list-timers` | `sudo loginctl enable-linger <user>` |
| Kein Netz nach Reboot | Netplan fehlerhaft | `ip a`, `sudo netplan try` | `sudo netplan apply` |
| Kein Autologin | `autologin.conf` fehlt / falsch | `systemctl cat getty@tty1` | Siehe installation.md, Schritt 4 |

## Befehlsreferenz

### Service

```bash
systemctl --user status iptv-relay.service
systemctl --user restart iptv-relay.service
journalctl --user -u iptv-relay.service -f
```

### Logs

```bash
tail -f ~/.local/state/iptv-relay/iptv-player.log
tail -f ~/.local/state/iptv-relay/iptv-player-error.log
tail -f ~/.local/state/iptv-relay/watchdog.log
```

### Netzwerk & Multicast

```bash
ip -br a
ip route show default
ip maddr show
ffprobe udp://@224.x.x.x:5000
```

### Cron & Timer

```bash
crontab -l
grep CRON /var/log/syslog | tail -20
systemctl --user list-timers
```

### Konsolen

| Tasten | Ziel |
|---|---|
| Strg + Alt + F1 | tty1 – IPTV-Stream |
| Strg + Alt + F3 | tty3 – Administration |

## Beispiel: Watchdog-Log

```
2026-06-25 04:20:00 - ==================================================
2026-06-25 04:20:00 - INFO: Watchdog gestartet
2026-06-25 04:20:00 - OK: Netzwerk aktiv (Interface: wlan0, IP: 10.x.x.100, Gateway: 10.x.x.254)
2026-06-25 04:20:00 - OK: Service iptv-relay.service läuft
2026-06-25 04:20:00 - OK: ffplay läuft (PID: 3180)
2026-06-25 04:20:00 - INFO: Watchdog beendet
2026-06-25 04:20:00 - ==================================================
```
