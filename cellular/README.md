# Cellular (joe.cellular)

Omarchy bar widget for the built-in WWAN modem (Sierra Wireless EM7455).

- **Bar icon**: signal strength when connected; dimmed when not; SIM-alert
  glyph for SIM/carrier problems; crossed-out when the radio is off.
- **Left click**: open the panel. **Right click**: cellular radio on/off.
- **Panel**: carrier + status, on/off switch, hint explaining any problem,
  signal/technology, home/roaming, IP, data used this session, APN, modem,
  and a Connect/Disconnect button. Keyboard: arrows move, Enter activates.

Requires `modemmanager` and a NetworkManager `gsm` connection profile
("Mobile Broadband"). Radio on/off is `nmcli radio wwan`, which NetworkManager
remembers across reboots.

Files: `cellular-status` (read-only state helper), `Model.js` (pure logic,
tested by `node tests/model.test.js`), `Panel.qml` (UI), `i18n/en.json`.

Setting: `refreshIntervalSec` (default 15; the panel polls every 3s while open):

    omarchy bar set joe.cellular refreshIntervalSec 30
