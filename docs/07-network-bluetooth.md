# Network & Bluetooth Control Center

New component — no direct prior equivalent in this repo (DMS almost
certainly has *some* network/bluetooth quick-settings, but there's no
dedicated doc/dotfile for it in `linux_conf-main`, so nothing here is being
replaced, only added).

## Keybinding

| Bind | Status |
|---|---|
| *(none — click-only)* | **Deferred** |

The spec's own activation section only mandates opening via clicking the
Wi-Fi/Bluetooth/Network icon in the Bar's system-controls section (see
[02-bar.md](02-bar.md) Section 5/6), and says a keyboard shortcut "may also
be added later." Since the reference repo has nothing bound to this action
today, don't invent a new global bind speculatively — wire the Bar's icon
click to `qs -c desktopdesigner ipc call networkCenter toggle` and leave a
keybind as a later config addition if it turns out to be wanted. YAGNI.

## Directory structure

```
NetworkCenter/
├── NetworkCenter.qml
├── Overlay.qml        # 35–45% dim scrim, slight blur, centered dialog (900–1000 × 650–750px)
├── TabBar.qml          # Wi-Fi | Bluetooth
├── StatusBar.qml
├── Wifi/
│   ├── WifiPage.qml  NetworkList.qml  NetworkCard.qml
│   ├── PasswordDialog.qml  NetworkActions.qml
├── Bluetooth/
│   ├── BluetoothPage.qml  DeviceList.qml  DeviceCard.qml  DeviceActions.qml
├── Services/
│   ├── NetworkManager.qml   # shared with Bar's system-controls status icon
│   ├── BlueZ.qml            # same
│   └── DBusInterface.qml
└── Components/
```

`Services/NetworkManager.qml` and `Services/BlueZ.qml` here should be the
*same* service instances the Bar's System section (02-bar.md) reads for its
status icons — both live under the shared `desktopdesigner/Services/`
(see [00-overview.md](00-overview.md)), not duplicated per-component.

## Wi-Fi — via NetworkManager DBus directly

Interaction model borrows from **Impala**'s keyboard-driven workflow (spec
reference), but implemented natively against
`org.freedesktop.NetworkManager` over DBus — not by embedding Impala as a
TUI. Key DBus objects:

- `org.freedesktop.NetworkManager.Device.Wireless` — `RequestScan()`,
  `AccessPoints` property, `PropertiesChanged` signal for live updates (no
  polling needed once subscribed).
- `org.freedesktop.NetworkManager.Settings` — saved connection profiles
  (for "Saved" sort bucket, Forget action).
- `org.freedesktop.NetworkManager.Connection.Active` — current connection
  state, signal strength, IP/DNS/gateway details shown in the "current
  connection" header.

`nmcli` is fine as a fallback for anything the DBus API makes awkward (e.g.
`nmcli dev wifi connect` for the actual connect-with-password flow is
simpler than hand-rolling the `AddAndActivateConnection` DBus call with all
its settings dict shape) — the spec says "do not shell out to nmcli **unless
absolutely necessary**," which is a real allowance, not a hard ban. Prefer
DBus for anything read-only or event-driven (scanning results, status);
shelling out for one-shot mutating actions (connect/forget) is acceptable if
it measurably shortens the implementation.

## Bluetooth — via BlueZ DBus directly

`org.bluez.Adapter1` (power/discoverable/scan), `org.bluez.Device1`
(Connect/Disconnect/Pair/Trusted/Remove), `org.bluez.Battery1` (device
battery %, where supported). Same "DBus first, no `bluetoothctl`" rule.
Interaction model borrows from **Bluetuith**'s workflow (pairing/connecting/
trusting/rename/device-info), reimplemented natively.

## Search

`/` or `Ctrl+F` opens a search field filtering SSID/device-name/MAC — local
to this overlay's focus scope, not global.

## Setup checklist

1. `Services/NetworkManager.qml` — get live AP list + signal strength
   updating with zero polling before any UI; verify in `temp/` against
   `busctl monitor org.freedesktop.NetworkManager` to confirm signals fire
   as expected.
2. `Services/BlueZ.qml` — same verification approach against `org.bluez`.
3. `Wifi/WifiPage.qml` + `NetworkList.qml`/`NetworkCard.qml`, read-only
   first (no connect/forget yet).
4. `PasswordDialog.qml` + `NetworkActions.qml` — connect/disconnect/forget.
5. `Bluetooth/` pages, same read-only-first approach, then actions.
6. `Overlay.qml` + `TabBar.qml` wrapping both, wire to the Bar's
   system-controls icon click.
7. Keyboard navigation (↑↓/←→/Enter/Space/Tab/Esc/search) last, once the
   two pages' content is stable.

## Deferred

VPN, Ethernet, mobile broadband, airplane mode, hotspot, WireGuard/OpenVPN/
Tailscale/Zerotier, network usage graphs, Bluetooth audio-profile switching,
media controls, nearby-share, battery history, QR-share for Wi-Fi, file
transfer over Bluetooth — all spec'd as future. Build the Wi-Fi/Bluetooth
tabs only.
