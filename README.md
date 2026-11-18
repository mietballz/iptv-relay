# IPTV-Relay – Multicast-Stream als 24/7-Kiosk auf einem HDMI-TV

Ein schlanker Mini-PC empfängt einen **UDP-Multicast-IPTV-Stream** aus dem Firmennetz und gibt ihn **vollautomatisch, rund um die Uhr und ohne manuelle Eingriffe** im Vollbild auf einem HDMI-Fernseher wieder – inklusive HDMI-Ton, Selbstheilung und LAN/WLAN-Fallback.

Das Projekt ist im produktiven Einsatz in einer Hotelumgebung entstanden. Alle Benutzernamen, IP-Adressen und Zugangsdaten in diesem Repository sind anonymisiert.

> **English summary:** A small Ubuntu mini PC receives a UDP multicast IPTV stream and plays it full-screen on an HDMI TV – fully automated, 24/7, with no manual intervention. It uses `ffplay`, a systemd user service with autologin on tty1, HDMI audio via PulseAudio, a Bash watchdog that self-heals network and player issues, Netplan LAN/Wi-Fi failover and a daily scheduled restart. Built for production use in a hotel environment; all names and addresses are anonymised. Documentation is in German.

![Plattform](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?logo=ubuntu&logoColor=white)
![ffmpeg](https://img.shields.io/badge/ffmpeg-ffplay-007808?logo=ffmpeg&logoColor=white)
![systemd](https://img.shields.io/badge/systemd-User--Service-informational)
![Shell](https://img.shields.io/badge/Bash-Watchdog-4EAA25?logo=gnubash&logoColor=white)
![Lizenz](https://img.shields.io/badge/Lizenz-MIT-blue)

---

## Features

| Anforderung | Umsetzung |
|---|---|
| Plug & Play – startet nach Stromausfall von selbst | Autologin auf tty1 + systemd User-Service |
| 24/7-Betrieb ohne Desktop-Umgebung | `ffplay` direkt auf tty1, kein GUI-Overhead |
| HDMI-Audio | PulseAudio-Standard-Sink per `ExecStartPre` |
| Selbstheilung | Bash-Watchdog (Netzwerk, Service, Prozess) alle 5 Min. |
| Ausfallsicherheit Netzwerk | Netplan: LAN bevorzugt, WLAN als Fallback |
| Langzeitstabilität | Täglicher Neustart 04:15 Uhr (Cron bzw. systemd-Timer) |
| Nachvollziehbarkeit | Getrennte Logs für Player, Fehler und Watchdog |
| Wartbarkeit | Zentrale Konfigurationsdatei, Installationsskript |

## Architektur

```mermaid
flowchart TD
    A[Boot: UEFI → GRUB → Kernel] --> B[getty@tty1<br/>agetty --autologin]
    B --> C[User-Session<br/>systemd --user]
    C --> D[iptv-relay.service]
    D -->|ExecStartPre| E[pactl: HDMI-Sink setzen]
    D -->|ExecStart| F[iptv-player.sh → ffplay -fs]
    M[(Multicast<br/>udp://@224.x.x.x:5000)] -->|IGMP Join| F
    F --> TV[HDMI-TV<br/>Bild + Ton]
    W[Cron */5: iptv-watchdog.sh] -.prüft.-> N[Netzwerk / Gateway]
    W -.prüft / restart.-> D
    T[04:15 Reboot / Timer] -.-> A
```

## Repository-Struktur

```
iptv-relay/
├── bin/
│   ├── iptv-player.sh          # Startet ffplay mit Werten aus der Konfiguration
│   └── iptv-watchdog.sh        # Selbstheilung: Netzwerk, Service, ffplay
├── config/
│   └── iptv-relay.env.example  # Zentrale Konfiguration (Stream-URL, HDMI-Sink, …)
├── systemd/
│   ├── user/
│   │   ├── iptv-relay.service
│   │   ├── iptv-relay-restart.service
│   │   └── iptv-relay-restart.timer
│   └── system/getty@tty1.service.d/
│       └── autologin.conf
├── netplan/01-netcfg.yaml.example
├── cron/
│   ├── crontab.user            # Watchdog alle 5 Minuten
│   └── crontab.system          # Täglicher Reboot 04:15 Uhr
├── docs/
│   ├── installation.md
│   ├── audio-hdmi.md
│   └── troubleshooting.md
└── install.sh
```

## Schnellstart

```bash
sudo apt install ffmpeg pulseaudio-utils iproute2 iputils-ping cron
```

```bash
git clone https://github.com/mietballz/iptv-relay.git && cd iptv-relay
```

```bash
./install.sh
```

```bash
nano ~/.config/iptv-relay/iptv-relay.env
```

```bash
sudo loginctl enable-linger "$USER"
systemctl --user start iptv-relay.service
```

Die systemweiten Schritte (Autologin, Netplan, Reboot-Cron, sudoers für den Watchdog) sind in [docs/installation.md](docs/installation.md) beschrieben.

## Der Kern: ffplay-Aufruf

```bash
ffplay -i udp://@224.x.x.x:5000 -fs -window_title "IPTV" -volume 100 -af "volume=2"
```

| Option | Bedeutung |
|---|---|
| `udp://@…` | Das `@` lässt ffplay der Multicast-Gruppe beitreten (IGMP Join) |
| `-fs` | Vollbild auf dem angeschlossenen TV |
| `-window_title` | Erleichtert die Prozessidentifikation |
| `-volume 100` | SDL-Lautstärke (Standard ist teils stumm) |
| `-af "volume=2"` | Zusätzliche Verstärkung per Audiofilter |

## Lessons Learned

**HDMI-Ton lässt sich in ffplay nicht direkt auswählen.** ffplay nutzt über SDL2 immer den Standard-Sink von PulseAudio. Versuche mit `-f alsa -device hw:0,3`, `AUDIODEV`, `SDL_AUDIO_DEVICE_NAME` oder `-audio_device` schlugen alle fehl. Die Lösung ist, den Standard-Sink vor dem Start per `pactl set-default-sink` auf HDMI zu setzen. Details in [docs/audio-hdmi.md](docs/audio-hdmi.md).

**`systemctl --user` aus Cron braucht Umgebungsvariablen.** Cron startet ohne Session-Kontext. Der Watchdog setzt daher `XDG_RUNTIME_DIR` und `DBUS_SESSION_BUS_ADDRESS` selbst, sonst erreicht er den User-Manager nicht.

**User-Services ohne Linger sterben mit der Session.** `loginctl enable-linger` sorgt dafür, dass User-Units und Timer unabhängig vom Login weiterlaufen.

## Betrieb

```bash
systemctl --user status iptv-relay.service
journalctl --user -u iptv-relay.service -f
tail -f ~/.local/state/iptv-relay/watchdog.log
```

Fehlermatrix und Befehlsreferenz: [docs/troubleshooting.md](docs/troubleshooting.md)

## Lizenz

MIT – siehe [LICENSE](LICENSE).
