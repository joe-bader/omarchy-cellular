# omarchy-cellular

An [Omarchy](https://omarchy.org/) bar widget for a built-in WWAN/LTE modem:
signal strength and carrier in the bar, with mobile data on/off and
connection details in its panel.

- **Bar icon**: signal strength when connected; dimmed when not; SIM-alert
  glyph for SIM/carrier problems; crossed-out when the radio is off.
- **Left click**: open the panel. **Right click**: cellular radio on/off.
- **Panel**: carrier and status, on/off switch, a hint explaining any problem
  (no SIM, SIM locked, SIM not activated, registration denied), signal and
  technology, home/roaming, IP address, data used this session, APN, modem,
  and a Connect/Disconnect button. Keyboard: arrows move, Enter activates.

## Install

```bash
omarchy plugin add https://github.com/joe-bader/omarchy-cellular.git --enable
```

Update later with `omarchy plugin update joe.cellular`.

## Requirements

The modem must be driven by ModemManager, with a NetworkManager mobile
broadband profile:

```bash
omarchy pkg add modemmanager
sudo systemctl enable --now ModemManager
nmcli connection add type gsm ifname '*' con-name "Mobile Broadband" gsm.auto-config yes
```

`gsm.auto-config` picks the APN from the carrier database. If your carrier
isn't listed, set it yourself:

```bash
nmcli connection modify "Mobile Broadband" gsm.auto-config no gsm.apn <your-apn>
```

Radio on/off uses `nmcli radio wwan`, which NetworkManager remembers across
reboots.

## Settings

`refreshIntervalSec` (default 15; the panel polls every 3s while open):

```bash
omarchy bar set joe.cellular refreshIntervalSec 30
```

## Development

- `cellular-status` — read-only helper that prints modem state from `mmcli`
  and `nmcli` as `key<TAB>value` lines.
- `Model.js` — pure status logic; test with `node tests/model.test.js`.
- `Panel.qml` — the bar icon and panel.
- `i18n/en.json` — strings; add `<lang>.json` files for translations.

Tested with a Sierra Wireless EM7455.

## License

MIT
