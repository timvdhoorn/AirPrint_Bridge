# AirPrint Bridge - Custom Label Size Fork

Fork of [sapireli/AirPrint_Bridge](https://github.com/sapireli/AirPrint_Bridge) with support for **custom label sizes (100x150mm)** for thermal label printers like Zebra.

## What's Different

This fork adds:

- **Fixed 100x150mm label size** — forces all AirPrint-shared printers to advertise only a 100x150mm paper size (common shipping label format)
- **PPD stripping** — modifies the printer's PPD file so iOS only sees the custom label size, preventing users from accidentally selecting the wrong paper size
- **Automatic PPD backup & restore** — original PPD files are backed up before modification and restored on uninstall

This is useful when you have a thermal label printer (e.g. Zebra) connected to a Mac and want to print shipping labels directly from an iPhone/iPad via AirPrint.

## Requirements

- **macOS** 10.15 (Catalina) or later
- A shared printer configured in **System Settings > Printers & Scanners**
- Printer sharing enabled in **System Settings > General > Sharing**

## Quick Start

### 1. Share Your Printer

1. Go to **System Settings > General > Sharing**
2. Enable **Printer Sharing**
3. Select the printer(s) you want to share

### 2. Download

```bash
git clone https://github.com/timvdhoorn/AirPrint_Bridge.git
cd AirPrint_Bridge
chmod +x airprint_bridge.sh
```

### 3. Test

Run in test mode first to verify everything works:

```bash
sudo ./airprint_bridge.sh -t
```

This will:
1. Detect shared printers
2. Strip the PPD to only offer the 100x150mm label size
3. Register the printer(s) via Bonjour/dns-sd
4. Keep running in the foreground — test printing from your iOS device

Press **CTRL-C** to stop.

### 4. Install

Once testing confirms it works:

```bash
sudo ./airprint_bridge.sh -i
```

This installs a `launchd` service that starts automatically on boot, so your label printer is always available via AirPrint.

### 5. Uninstall

```bash
sudo ./airprint_bridge.sh -u
```

This removes the service, restores original PPD files, and reverts any CUPS configuration changes.

## Customizing the Label Size

The label size is configured at the top of `airprint_bridge.sh`:

```bash
# Custom label size: 100x150mm
# 100mm = 283.46pt, 150mm = 425.20pt
CUSTOM_WIDTH_PT=284
CUSTOM_HEIGHT_PT=426
CUSTOM_LABEL="100x150"
```

To use a different size, update these values. Dimensions are in PostScript points (1 inch = 72 points, 1 mm = 2.8346 points).

## Options

| Flag | Description |
|------|-------------|
| `-t` | Test mode (dry run, CTRL-C to exit) |
| `-i` | Install as persistent service |
| `-u` | Uninstall service and restore settings |
| `-f` | Custom path for the launcher script |
| `-h` | Show help |

## How It Works

1. Detects shared printers on your Mac
2. Strips the printer's PPD file to only contain the 100x150mm size
3. Generates URF capability records for each printer
4. Registers printers via `dns-sd` as AirPrint-compatible
5. Installs a `launchd` daemon so the service survives reboots

## Troubleshooting

- **Printer not visible on iOS**: Make sure printer sharing is enabled and the Mac's firewall allows CUPS
- **Wrong paper size on iOS**: Run uninstall (`-u`) then reinstall (`-i`) to refresh the PPD
- **Permission errors**: Always run with `sudo`
- **Restore original PPD**: Uninstall (`-u`) automatically restores backed-up PPD files

## Credits

- Original project: [sapireli/AirPrint_Bridge](https://github.com/sapireli/AirPrint_Bridge)
- Inspired by [@PeterCrozier](https://github.com/PeterCrozier/AirPrint)

## License

MIT License — see [LICENSE](LICENSE) for details.
