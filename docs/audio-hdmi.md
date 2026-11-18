# HDMI-Audio mit ffplay

## Problem

ffplay hat keine Option, um ein bestimmtes Audiogerät zu wählen. Es gibt den Ton über SDL2 an den
**Standard-Sink von PulseAudio** aus. Nach der Installation war das die analoge Klinkenbuchse – der TV blieb stumm.

## Fehlgeschlagene Ansätze

| Versuch | Ergebnis |
|---|---|
| `-f alsa -device hw:0,3` | `Unknown PCM` – die Stream-URL wurde als Audiogerät interpretiert |
| `AUDIODEV=hw:0,3` | Von ffplay/SDL2 ignoriert |
| `SDL_AUDIO_DEVICE_NAME=plughw:0,3` | `No such device` |
| `-f pulse -audio_device <SINK>` | `Option not found` – gibt es in ffplay nicht |

## Lösung

Den Standard-Sink auf HDMI setzen, **bevor** ffplay startet. Im Service geschieht das per `ExecStartPre`,
damit es nach jedem Neustart automatisch greift.

Sinks anzeigen:

```bash
pactl list sinks short
```

HDMI als Standard setzen:

```bash
pactl set-default-sink alsa_output.pci-0000_00_1f.3.hdmi-stereo
```

Prüfen:

```bash
pactl info | grep Default
```

Hardware direkt testen (ALSA, an PulseAudio vorbei):

```bash
speaker-test -D hw:0,3 -c 2
```

Der Name des HDMI-Sinks ist hardwareabhängig und wird in `iptv-relay.env` als `HDMI_SINK` hinterlegt.
