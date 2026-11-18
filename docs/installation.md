# Installation

Zielsystem: Ubuntu 24.04 LTS (Server oder Minimal) auf einem Mini-PC mit HDMI-Ausgang.
In den Beispielen heißt der Kiosk-Benutzer `iptv`.

## 1. Pakete

```bash
sudo apt update
sudo apt install ffmpeg pulseaudio pulseaudio-utils iproute2 iputils-ping cron
```

## 2. Benutzerteil (ohne root)

```bash
git clone https://github.com/mietballz/iptv-relay.git
cd iptv-relay
./install.sh
```

Danach die Konfiguration anpassen – mindestens `STREAM_URL`:

```bash
nano ~/.config/iptv-relay/iptv-relay.env
```

## 3. Linger aktivieren

Damit User-Service und Timer ohne aktive Login-Session laufen:

```bash
sudo loginctl enable-linger iptv
```

## 4. Autologin auf tty1

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
```

```bash
sudo cp systemd/system/getty@tty1.service.d/autologin.conf /etc/systemd/system/getty@tty1.service.d/
```

Benutzernamen in der Datei prüfen, dann:

```bash
sudo systemctl daemon-reload
```

## 5. Netzwerk (LAN + WLAN-Fallback)

```bash
sudo cp netplan/01-netcfg.yaml.example /etc/netplan/01-netcfg.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
```

SSID und Passwort eintragen, dann testen:

```bash
sudo netplan try
```

## 6. sudoers für den Watchdog

Der Watchdog darf bei Netzwerkproblemen `netplan apply` ohne Passwort ausführen – und nur das:

```bash
echo 'iptv ALL=(root) NOPASSWD: /usr/sbin/netplan apply' | sudo tee /etc/sudoers.d/iptv-watchdog
sudo chmod 440 /etc/sudoers.d/iptv-watchdog
sudo visudo -c
```

## 7. Täglicher Reboot

Entweder systemweit per Cron (startet den ganzen PC neu):

```bash
echo '15 4 * * * root /sbin/reboot' | sudo tee -a /etc/crontab
```

oder nur den Player per systemd-Timer neu starten (von `install.sh` bereits aktiviert):

```bash
systemctl --user list-timers
```

## 8. Test

```bash
ffprobe udp://@224.x.x.x:5000
systemctl --user start iptv-relay.service
~/.local/bin/iptv-watchdog.sh && tail ~/.local/state/iptv-relay/watchdog.log
```

Abschließend einmal neu starten und prüfen, ob der Stream ohne Eingriff erscheint.
