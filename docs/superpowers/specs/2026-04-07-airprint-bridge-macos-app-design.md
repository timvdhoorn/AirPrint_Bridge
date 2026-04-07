# AirPrint Bridge — macOS App Design Spec

## Overview

Convert the existing AirPrint Bridge bash script into a native macOS SwiftUI app with a menu bar interface. The app makes non-AirPrint printers (primarily Zebra label printers) accessible to iOS devices via AirPrint, targeting a specific client with minimal technical knowledge.

## Developer

**Labels en Meer BV** — Dutch B2B company specializing in label printing solutions: label printers, barcode scanners, label software, consumables, and service & support.
- Heijligerweg 2, 4906MJ Oosterhout
- 085 303 7132 | info@labelsenmeer.nl
- Bundle identifier prefix: `nl.labelsenmeer`

## Target

- **Audience**: Specific client — minimal technical skills, must "just work"
- **Platform**: macOS 13 Ventura and later
- **Signing**: Developer ID certificate (hardened runtime)
- **Distribution**: Direct to client (not App Store)

## Architecture

### Two-component design

```
┌─────────────────────────────┐      ┌──────────────────────────────┐
│  Menu Bar App (user-space)  │      │  LaunchDaemon (root, boot)   │
│                             │      │                              │
│  - SwiftUI MenuBarExtra     │─────▶│  - Reads shared config       │
│  - Settings window          │config│  - CUPS/PPD modifications     │
│  - Printer discovery (read) │      │  - dns-sd registrations      │
│  - Config writes            │      │  - Runs continuously         │
│  - SMAppService management  │SIGHUP│  - Restarts on config change │
└─────────────────────────────┘      └──────────────────────────────┘
```

**Menu Bar App** (`AirPrint Bridge.app`)
- SwiftUI app with `MenuBarExtra` as primary scene
- `Settings` scene for preferences (Cmd+,)
- Discovers shared CUPS printers (read-only, via `lpstat`)
- Writes configuration to shared plist
- Manages LaunchDaemon lifecycle via `SMAppService.daemon()`

**LaunchDaemon** (`nl.labelsenmeer.airprint-bridge.daemon`)
- Swift CLI binary embedded in app bundle at `Contents/Library/LaunchDaemons/`
- Runs as root at boot (before login), `KeepAlive: true`
- Reads config, modifies CUPS/PPD, registers dns-sd services
- Listens for `SIGHUP` to reload config without restart

### Config storage

Shared `UserDefaults` suite: `nl.labelsenmeer.airprint-bridge`

```
{
  "enabledPrinters": {
    "Zebra_DHL": { "width": 100, "height": 40 },
    "Brother_Kantoor": { "width": 210, "height": 297 }
  },
  "defaultPaperWidth": 100,
  "defaultPaperHeight": 40,
  "showMenuBarIcon": true,
  "launchAtBoot": true
}
```

### Signing requirements

- App signed with Developer ID certificate
- Daemon binary signed with same Team ID
- Hardened Runtime enabled (required for `SMAppService`)
- No App Sandbox (direct distribution, not App Store — app needs to run `lpstat`, send signals)
- `Info.plist` keys for `SMAppService` daemon registration
- Daemon plist embedded at `Contents/Library/LaunchDaemons/` (required by `SMAppService`)

## UI Design

### Menu Bar Popover (primary interface)

`MenuBarExtra` with `.menuBarExtraStyle(.window)` — popover panel.

**Content:**
- Header: "AirPrint Bridge" + status badge ("Actief" / "Gestopt")
- Subtitle: "X van Y printers gedeeld"
- Printer list: each printer shows:
  - Printer name (bold)
  - Printer model + paper size (secondary text)
  - Toggle (on/off) to enable/disable AirPrint sharing
  - Disabled printers shown at reduced opacity
- Footer: "Instellingen" link, "Vernieuw" button, "Stop" button

**`isInserted:` binding** with `@AppStorage("showMenuBarIcon")` — allows hiding the icon entirely. When hidden, user reopens settings via Spotlight or relaunching the app.

### Settings Window (Cmd+,)

`Settings` scene with `TabView` — two tabs:

**Tab 1: Algemeen**
- "Start bij opstarten" checkbox — toggles LaunchDaemon via `SMAppService`
  - Subtitle: "Draait als achtergrondservice, ook zonder dat iemand is ingelogd"
  - Triggers admin password prompt on first enable
- "Toon icoontje in menubalk" checkbox — toggles `isInserted`
  - Subtitle: "Als uitgeschakeld, open Instellingen via Spotlight of de app opnieuw"
- "Standaard papierformaat" — width x height in mm
  - Used as default for newly discovered printers
  - Existing printers keep their individual setting

**Tab 2: Printers**
- List of all shared CUPS printers
- Per printer:
  - Name + model (read-only, from CUPS)
  - Toggle to enable/disable AirPrint sharing
  - Paper size: width x height in mm (editable per printer)
- Changes applied immediately — daemon receives SIGHUP, restarts dns-sd

## Core Logic (daemon)

Ported from existing `airprint_bridge.sh`. The daemon performs:

### 1. CUPS permission check
- Verify `Allow @LOCAL` in `/etc/cups/cupsd.conf`
- Auto-fix with backup if missing (same as current script)
- Verify shared printers allow all users (`lpadmin -p <name> -u allow:all`)

### 2. Firewall check
- If macOS firewall enabled, ensure `cupsd` is allowed
- Uses `socketfilterfw` commands (same as current script)

### 3. PPD stripping
- For each enabled printer, strip PPD to only the configured paper size
- Backup original PPD to `.original` before modification
- Convert mm dimensions to points (mm * 2.8346)
- Disable `CustomPageSize` to prevent iOS from generating arbitrary sizes

### 4. dns-sd registration
- For each enabled printer, register AirPrint TXT records via `dns-sd -R`
- TXT records include: URF capabilities, color/duplex flags, printer model, paper size
- URF generation logic ported from existing script (inspects `lpoptions`)

### 5. Cleanup on disable/uninstall
- Restore original PPDs from `.original` backups
- Revert CUPS config from `.bak` backup
- Kill dns-sd registration processes
- Unregister LaunchDaemon via `SMAppService`

## Communication: App ↔ Daemon

1. **App writes config** to shared `UserDefaults` suite
2. **App sends `SIGHUP`** to daemon process (found via PID file at `/var/run/airprint-bridge.pid`)
3. **Daemon catches `SIGHUP`**, re-reads config, tears down existing dns-sd processes, re-runs setup with new config
4. **Status reporting**: daemon writes status to a shared file (`/tmp/airprint-bridge-status.json`) containing running state and per-printer status. App reads this for the popover display.

## Project Structure

```
AirPrintBridge/
├── AirPrintBridge.xcodeproj
├── AirPrintBridge/                    # Menu bar app target
│   ├── AirPrintBridgeApp.swift        # @main, MenuBarExtra + Settings scenes
│   ├── Views/
│   │   ├── PopoverView.swift          # Menu bar popover content
│   │   ├── SettingsGeneralView.swift  # Algemeen tab
│   │   └── SettingsPrintersView.swift # Printers tab
│   ├── Models/
│   │   ├── PrinterConfig.swift        # Printer config model
│   │   ├── AppConfig.swift            # App-wide config with @AppStorage
│   │   └── PrinterDiscovery.swift     # CUPS printer discovery (lpstat)
│   ├── Services/
│   │   ├── DaemonManager.swift        # SMAppService wrapper
│   │   └── StatusReader.swift         # Reads daemon status file
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── AirPrintBridge.entitlements
├── AirPrintBridgeDaemon/             # LaunchDaemon target (CLI)
│   ├── main.swift                    # Entry point, signal handling
│   ├── CUPSManager.swift             # CUPS config + PPD stripping
│   ├── DNSSDRegistrar.swift          # dns-sd process management
│   ├── URFGenerator.swift            # URF capability detection
│   ├── FirewallManager.swift         # Firewall check/fix
│   ├── ConfigReader.swift            # Reads shared UserDefaults
│   └── Info.plist                    # LaunchDaemon plist (embedded)
└── docs/
```

## Error Handling

- **No shared printers found**: popover shows "Geen gedeelde printers gevonden" with link to macOS printer settings
- **Daemon not running**: status badge shows "Gestopt" in red, "Start" button replaces "Stop"
- **Admin password denied**: show alert explaining why admin access is needed
- **CUPS config fix fails**: restore from backup, show error in popover with "Probeer opnieuw" button
- **PPD backup missing**: skip PPD modification, log warning, show printer as "Configuratie onvolledig"

## Testing Strategy

- **Unit tests**: config read/write, mm-to-points conversion, URF generation logic
- **Integration tests**: CUPS printer discovery with mock `lpstat` output, PPD stripping with sample PPD files
- **Manual tests**: full flow on macOS — install daemon, toggle printers, verify iOS AirPrint discovery
- **Signing verification**: `codesign --verify` on both app and daemon binary

## Out of Scope

- App Store distribution (uses privileged LaunchDaemon)
- Auto-update mechanism (manual update by client for now)
- Multiple paper sizes per printer (one size per printer)
- Network printer discovery (only local CUPS shared printers)
- Localization beyond Dutch (single client)
