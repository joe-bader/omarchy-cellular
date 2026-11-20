# omarchy-plugins

Shell plugins for [Omarchy](https://omarchy.org/)'s bar.

| Plugin | ID | What it does |
|--------|----|--------------|
| [Cellular](cellular/) | `joe.cellular` | Signal strength and carrier for a built-in WWAN/LTE modem, with mobile data on/off and connection details. |

## Install

Each plugin lives in its own folder. Link (or copy) a folder into
`~/.config/omarchy/plugins/`, then enable it:

```bash
git clone https://github.com/joe-bader/omarchy-plugins.git ~/omarchy-plugins
ln -s ~/omarchy-plugins/cellular ~/.config/omarchy/plugins/joe.cellular
omarchy plugin enable joe.cellular --before omarchy.network
```

With a symlink, `git pull` updates the plugin; the shell reloads it on its own.

## Cellular requirements

The modem has to be driven by ModemManager, with a NetworkManager mobile
broadband profile:

```bash
omarchy pkg add modemmanager
sudo systemctl enable --now ModemManager
nmcli connection add type gsm ifname '*' con-name "Mobile Broadband" gsm.auto-config yes
```

See [cellular/README.md](cellular/README.md) for details.

## License

MIT
