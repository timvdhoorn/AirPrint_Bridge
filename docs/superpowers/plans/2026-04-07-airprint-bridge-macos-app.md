# AirPrint Bridge macOS App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the existing `airprint_bridge.sh` bash script into a native macOS SwiftUI menu bar app with a LaunchDaemon for background AirPrint bridging.

**Architecture:** Two-target Xcode project — a SwiftUI menu bar app (`AirPrintBridge.app`) that provides the UI and config, and a Swift CLI LaunchDaemon (`AirPrintBridgeDaemon`) that runs as root at boot to modify CUPS/PPD and register dns-sd services. The app writes config to a shared `UserDefaults` suite and signals the daemon via `SIGHUP`. The daemon writes status to `/tmp/airprint-bridge-status.json` for the app to read.

**Tech Stack:** Swift 5.9+, SwiftUI, macOS 13+ (Ventura), `SMAppService`, `UserDefaults` suite, `Process` (for shell commands), XCTest

**macOS 13 constraint:** Use `ObservableObject`/`@Published`/`@StateObject`/`@ObservedObject`/`@EnvironmentObject` (NOT `@Observable`/`@Bindable`/`@Environment(Type.self)` which require macOS 14+). Use `tabItem` in Settings (NOT `Tab` API which requires macOS 15+).

**Spec:** `docs/superpowers/specs/2026-04-07-airprint-bridge-macos-app-design.md`
**Existing script:** `airprint_bridge.sh` — all daemon logic is ported from this.

---

## File Structure

```
AirPrintBridge/
├── AirPrintBridge.xcodeproj
├── AirPrintBridge/                          # Menu bar app target
│   ├── AirPrintBridgeApp.swift              # @main — MenuBarExtra + Settings scenes
│   ├── Views/
│   │   ├── PopoverView.swift                # Menu bar popover content
│   │   ├── SettingsGeneralView.swift        # "Algemeen" tab
│   │   └── SettingsPrintersView.swift       # "Printers" tab
│   ├── Models/
│   │   ├── PrinterConfig.swift              # Per-printer config (name, width, height, enabled)
│   │   ├── BridgeConfig.swift               # Full app config — reads/writes shared UserDefaults
│   │   └── PrinterDiscovery.swift           # Discovers shared CUPS printers via lpstat
│   ├── Services/
│   │   ├── DaemonManager.swift              # SMAppService wrapper for daemon lifecycle
│   │   └── StatusReader.swift               # Reads daemon status JSON
│   ├── Assets.xcassets                      # App icon + menu bar icon (SF Symbol)
│   ├── Info.plist
│   └── AirPrintBridge.entitlements
├── AirPrintBridgeDaemon/                    # LaunchDaemon CLI target
│   ├── main.swift                           # Entry point — signal handling, run loop, orchestration
│   ├── CUPSManager.swift                    # CUPS config check/fix + PPD stripping
│   ├── PPDStripper.swift                    # Pure PPD content transformation (testable)
│   ├── DNSSDRegistrar.swift                 # dns-sd process management
│   ├── URFGenerator.swift                   # URF capability string from lpoptions output
│   ├── TXTRecordBuilder.swift               # Builds AirPrint TXT record arrays
│   ├── FirewallManager.swift                # macOS firewall check/fix
│   ├── ConfigReader.swift                   # Reads shared UserDefaults suite
│   ├── StatusWriter.swift                   # Writes status JSON to /tmp
│   ├── ShellCommand.swift                   # Thin wrapper around Process for shell execution
│   └── Info.plist                           # LaunchDaemon plist (for SMAppService embedding)
├── Shared/                                  # Shared between both targets
│   ├── Constants.swift                      # Bundle IDs, suite name, paths
│   ├── PrinterConfig.swift                  # Shared Codable model
│   └── UnitConversion.swift                 # mm ↔ points conversion
├── AirPrintBridgeTests/                     # Unit tests (app + daemon logic)
│   ├── UnitConversionTests.swift
│   ├── URFGeneratorTests.swift
│   ├── PPDStripperTests.swift
│   ├── TXTRecordBuilderTests.swift
│   ├── ConfigReaderTests.swift
│   ├── PrinterDiscoveryTests.swift
│   └── StatusReaderTests.swift
└── TestFixtures/                            # Test data
    ├── sample_lpoptions_zebra.txt
    ├── sample_lpoptions_color.txt
    ├── sample_ppd_zebra.ppd
    └── sample_lpstat_output.txt
```

**Key design decisions:**
- `PPDStripper` is a pure function (String in, String out) extracted from `CUPSManager` so PPD transformation logic is fully unit-testable without touching the filesystem.
- `URFGenerator` parses lpoptions text output (not live commands) so it's testable with fixture files.
- `ShellCommand` is a thin wrapper so daemon managers can be tested by injecting mock command output.
- `Shared/` target contains models used by both app and daemon.

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `AirPrintBridge.xcodeproj` (via Xcode CLI)
- Create: `AirPrintBridge/AirPrintBridgeApp.swift`
- Create: `AirPrintBridge/Info.plist`
- Create: `AirPrintBridge/AirPrintBridge.entitlements`
- Create: `AirPrintBridgeDaemon/main.swift`
- Create: `AirPrintBridgeDaemon/Info.plist`
- Create: `Shared/Constants.swift`

> **Note:** This task creates the Xcode project structure. Use Xcode GUI or `xcodegen` for project generation. The steps below describe what to configure — not line-by-line Xcode project file edits.

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → macOS → App.
- Product Name: `AirPrintBridge`
- Team: Labels en Meer BV
- Organization Identifier: `nl.labelsenmeer`
- Interface: SwiftUI
- Language: Swift
- Uncheck "Include Tests" (we'll add manually)
- Deployment Target: macOS 13.0

- [ ] **Step 2: Configure app target**

In the AirPrintBridge target:
- Set bundle identifier: `nl.labelsenmeer.airprint-bridge`
- Signing: Developer ID (not App Store)
- Enable Hardened Runtime
- Disable App Sandbox (Info.plist: remove `com.apple.security.app-sandbox`)
- Add `LSUIElement = YES` to Info.plist (menu bar app, no Dock icon)

- [ ] **Step 3: Add daemon CLI target**

File → New → Target → macOS → Command Line Tool.
- Product Name: `AirPrintBridgeDaemon`
- Bundle Identifier: `nl.labelsenmeer.airprint-bridge.daemon`
- Language: Swift

- [ ] **Step 4: Configure daemon embedding**

In the AirPrintBridge app target → Build Phases → Embed Content:
- Add `AirPrintBridgeDaemon` binary
- Destination: `Contents/Library/LaunchDaemons/`
- Code Sign On Copy: Yes

- [ ] **Step 5: Create daemon Info.plist for SMAppService**

Create `AirPrintBridgeDaemon/Info.plist` and embed it at `Contents/Library/LaunchDaemons/`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>nl.labelsenmeer.airprint-bridge.daemon</string>
    <key>BundleProgram</key>
    <string>Contents/Library/LaunchDaemons/AirPrintBridgeDaemon</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>root</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>1</integer>
</dict>
</plist>
```

- [ ] **Step 6: Write minimal app entry point**

```swift
// AirPrintBridge/AirPrintBridgeApp.swift
import SwiftUI

@main
struct AirPrintBridgeApp: App {
    var body: some Scene {
        MenuBarExtra("AirPrint Bridge", systemImage: "printer.fill") {
            Text("AirPrint Bridge")
                .padding()
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Instellingen")
                .padding()
        }
    }
}
```

- [ ] **Step 7: Write minimal daemon entry point**

```swift
// AirPrintBridgeDaemon/main.swift
import Foundation

print("AirPrint Bridge Daemon starting...")
dispatchMain()
```

- [ ] **Step 8: Create shared constants**

```swift
// Shared/Constants.swift
import Foundation

enum AirPrintBridge {
    static let suiteName = "nl.labelsenmeer.airprint-bridge"
    static let daemonLabel = "nl.labelsenmeer.airprint-bridge.daemon"
    static let pidFilePath = "/var/run/airprint-bridge.pid"
    static let statusFilePath = "/tmp/airprint-bridge-status.json"
    static let cupsConfigPath = "/etc/cups/cupsd.conf"
    static let ppdBasePath = "/etc/cups/ppd"
    static let service = "_ipp._tcp.,_universal"
    static let domain = "local"
}
```

- [ ] **Step 9: Add test target**

File → New → Target → macOS → Unit Testing Bundle.
- Product Name: `AirPrintBridgeTests`
- Add both app and daemon source files to test target's compile sources as needed.

- [ ] **Step 10: Create TestFixtures group and directory**

Create `TestFixtures/` directory in the project root. Add it to the test target as a resource folder (Build Phases → Copy Bundle Resources).

- [ ] **Step 11: Build and verify**

Run: `Cmd+B` — both targets should compile successfully.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with app and daemon targets"
```

---

## Task 2: Shared Models — PrinterConfig & UnitConversion

**Files:**
- Create: `Shared/PrinterConfig.swift`
- Create: `Shared/UnitConversion.swift`
- Create: `AirPrintBridgeTests/UnitConversionTests.swift`

- [ ] **Step 1: Write failing tests for mm-to-points conversion**

```swift
// AirPrintBridgeTests/UnitConversionTests.swift
import XCTest
@testable import AirPrintBridge

final class UnitConversionTests: XCTestCase {
    func testMillimetersToPoints_100mm() {
        // 100mm * 2.8346 = 283.46, rounded to nearest int = 283
        XCTAssertEqual(UnitConversion.mmToPoints(100), 283)
    }

    func testMillimetersToPoints_40mm() {
        // 40mm * 2.8346 = 113.384, rounded = 113
        XCTAssertEqual(UnitConversion.mmToPoints(40), 113)
    }

    func testMillimetersToPoints_210mm() {
        // A4 width: 210mm * 2.8346 = 595.266, rounded = 595
        XCTAssertEqual(UnitConversion.mmToPoints(210), 595)
    }

    func testMillimetersToPoints_297mm() {
        // A4 height: 297mm * 2.8346 = 841.876, rounded = 842
        XCTAssertEqual(UnitConversion.mmToPoints(297), 842)
    }

    func testPointsToMillimeters_283() {
        // 283 / 2.8346 ≈ 99.84 → 100 (rounded)
        XCTAssertEqual(UnitConversion.pointsToMm(283), 100)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Cmd+U` or `xcodebuild test -scheme AirPrintBridge -destination 'platform=macOS'`
Expected: Compilation error — `UnitConversion` not defined.

- [ ] **Step 3: Implement UnitConversion**

```swift
// Shared/UnitConversion.swift
import Foundation

enum UnitConversion {
    private static let pointsPerMm: Double = 2.8346

    static func mmToPoints(_ mm: Int) -> Int {
        Int((Double(mm) * pointsPerMm).rounded())
    }

    static func pointsToMm(_ points: Int) -> Int {
        Int((Double(points) / pointsPerMm).rounded())
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Cmd+U`
Expected: All 5 tests PASS.

- [ ] **Step 5: Write PrinterConfig model**

```swift
// Shared/PrinterConfig.swift
import Foundation

struct PrinterConfig: Codable, Identifiable, Equatable {
    let name: String
    var widthMm: Int
    var heightMm: Int
    var enabled: Bool

    var id: String { name }

    var widthPoints: Int { UnitConversion.mmToPoints(widthMm) }
    var heightPoints: Int { UnitConversion.mmToPoints(heightMm) }
    var sizeLabel: String { "\(widthMm)x\(heightMm)" }
}
```

- [ ] **Step 6: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add Shared/PrinterConfig.swift Shared/UnitConversion.swift AirPrintBridgeTests/UnitConversionTests.swift
git commit -m "feat: add shared PrinterConfig model and unit conversion utilities"
```

---

## Task 3: URF Generation

**Files:**
- Create: `AirPrintBridgeDaemon/URFGenerator.swift`
- Create: `AirPrintBridgeTests/URFGeneratorTests.swift`
- Create: `TestFixtures/sample_lpoptions_zebra.txt`
- Create: `TestFixtures/sample_lpoptions_color.txt`

- [ ] **Step 1: Create test fixture — Zebra label printer lpoptions output**

```
// TestFixtures/sample_lpoptions_zebra.txt
ColorModel/Color Mode: *Gray
cupsPrintQuality/Quality: Draft *Normal High
PageSize/Media Size: w284h114
MediaType/MediaType: *labels
InputSlot/Media Source: *auto
```

- [ ] **Step 2: Create test fixture — color printer with duplex**

```
// TestFixtures/sample_lpoptions_color.txt
ColorModel/Color Mode: *RGB Gray
cupsPrintQuality/Quality: Draft *Normal High Photo
Orientation/Orientation: *Portrait Landscape
Duplex/Duplex: *None DuplexNoTumble DuplexTumble
PageSize/Media Size: w595h842
MediaType/MediaType: *plain glossy
InputSlot/Media Source: *auto tray-1 tray-2
```

- [ ] **Step 3: Write failing tests for URF generation**

```swift
// AirPrintBridgeTests/URFGeneratorTests.swift
import XCTest
@testable import AirPrintBridgeDaemon

final class URFGeneratorTests: XCTestCase {
    func testZebraPrinter_grayscaleNoColor() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)

        XCTAssertTrue(result.urf.hasPrefix("V1.4,"))
        XCTAssertTrue(result.urf.contains("W8"))
        XCTAssertFalse(result.urf.contains("SRGB24"))
        XCTAssertFalse(result.hasColor)
        XCTAssertFalse(result.hasDuplex)
    }

    func testColorPrinter_withDuplex() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)

        XCTAssertTrue(result.urf.contains("SRGB24"))
        XCTAssertTrue(result.urf.contains("W8"))
        XCTAssertTrue(result.hasColor)
        XCTAssertTrue(result.hasDuplex)
        XCTAssertTrue(result.urf.contains("DM2"))
        XCTAssertTrue(result.urf.contains("DM3"))
    }

    func testEmptyInput_returnsNone() {
        let result = URFGenerator.generate(from: "")
        XCTAssertEqual(result.urf, "none")
        XCTAssertFalse(result.hasColor)
        XCTAssertFalse(result.hasDuplex)
    }

    func testQualityCodes() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)

        XCTAssertTrue(result.urf.contains("PQ1")) // Draft
        XCTAssertTrue(result.urf.contains("PQ2")) // Normal
        XCTAssertTrue(result.urf.contains("PQ3")) // High
        XCTAssertTrue(result.urf.contains("PQ4")) // Photo
    }

    func testMediaTypeCodes() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)

        XCTAssertTrue(result.urf.contains("MT4")) // labels
    }

    private func loadFixture(_ name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: "txt")!
        return try! String(contentsOf: url)
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `Cmd+U`
Expected: Compilation error — `URFGenerator` not defined.

- [ ] **Step 5: Implement URFGenerator**

```swift
// AirPrintBridgeDaemon/URFGenerator.swift
import Foundation

struct URFResult {
    let urf: String
    let hasColor: Bool
    let hasDuplex: Bool
}

enum URFGenerator {
    static func generate(from lpoptions: String) -> URFResult {
        var codes: [String] = []
        var hasColor = false
        var hasDuplex = false

        func addUnique(_ code: String) {
            guard !codes.contains(code) else { return }
            codes.append(code)
        }

        for line in lpoptions.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("ColorModel") {
                let values = parseValues(trimmed)
                for value in values {
                    switch true {
                    case value.contains("Gray"), value.contains("Black"):
                        addUnique("W8")
                    case value.contains("RGB"), value.contains("Color"):
                        addUnique("SRGB24"); hasColor = true
                    case value.contains("AdobeRGB"):
                        addUnique("ADOBERGB24"); hasColor = true
                    case value.contains("CMYK"):
                        addUnique("CMYK32"); hasColor = true
                    default: break
                    }
                }
            } else if trimmed.contains("cupsPrintQuality/Quality:") {
                let values = parseValues(trimmed)
                for value in values {
                    switch true {
                    case value.contains("Draft"): addUnique("PQ1")
                    case value.contains("Normal"): addUnique("PQ2")
                    case value.contains("High"): addUnique("PQ3")
                    case value.contains("Photo"), value.contains("Best"): addUnique("PQ4")
                    default: break
                    }
                }
            } else if trimmed.contains("Orientation") || trimmed.contains("orientation") {
                let values = parseValues(trimmed)
                for value in values {
                    switch true {
                    case value.contains("Portrait"), value.contains("None"): addUnique("OR0")
                    case value.contains("ReverseLandscape"): addUnique("OR2")
                    case value.contains("ReversePortrait"): addUnique("OR3")
                    case value.contains("Landscape"): addUnique("OR1")
                    default: break
                    }
                }
            } else if trimmed.contains("Duplex") {
                let values = parseValues(trimmed)
                for value in values {
                    switch true {
                    case value.contains("None"), value.contains("Off"), value.contains("Simplex"):
                        addUnique("DM1")
                    case value.contains("DuplexNoTumble"):
                        addUnique("DM2"); hasDuplex = true
                    case value.contains("DuplexTumble"):
                        addUnique("DM3"); hasDuplex = true
                    case value.contains("DuplexManual"):
                        addUnique("DM4"); hasDuplex = true
                    default: break
                    }
                }
            } else if trimmed.contains("PageSize/Media Size:") {
                addUnique("MS_CUSTOM_100x150mm")
            } else if trimmed.contains("MediaType/MediaType:") {
                let values = parseValues(trimmed)
                for value in values {
                    let lower = value.lowercased()
                    switch true {
                    case lower.contains("stationery"), lower.contains("any"): addUnique("MT0")
                    case lower.contains("plain"): addUnique("MT1")
                    case lower.contains("recycled"): addUnique("MT2")
                    case lower.contains("transparency"): addUnique("MT3")
                    case lower.contains("labels"): addUnique("MT4")
                    case lower.contains("envelope"): addUnique("MT5")
                    case lower.contains("photographic"): addUnique("MT6")
                    case lower.contains("glossy"): addUnique("MT7")
                    case lower.contains("matte"): addUnique("MT8")
                    case lower.contains("cardstock"): addUnique("MT9")
                    case lower.contains("letterhead"): addUnique("MT10")
                    default: break
                    }
                }
            } else if trimmed.contains("InputSlot/Media Source:") {
                let values = parseValues(trimmed)
                for value in values {
                    let lower = value.lowercased()
                    switch true {
                    case lower.contains("auto"): addUnique("IS1")
                    case lower == "tray-1": addUnique("IS2")
                    case lower == "tray-2": addUnique("IS3")
                    case lower.contains("manual"): addUnique("IS4")
                    case lower == "tray-3": addUnique("IS5")
                    case lower == "tray-4": addUnique("IS6")
                    case lower == "tray-5": addUnique("IS7")
                    case lower.contains("envelope"): addUnique("IS8")
                    case lower.contains("multi"), lower.contains("multipurpose"): addUnique("IS9")
                    case lower.contains("photo"): addUnique("IS10")
                    default: break
                    }
                }
            }
        }

        if codes.isEmpty {
            return URFResult(urf: "none", hasColor: false, hasDuplex: false)
        }

        return URFResult(urf: "V1.4," + codes.joined(separator: ","), hasColor: hasColor, hasDuplex: hasDuplex)
    }

    private static func parseValues(_ line: String) -> [String] {
        guard let colonIndex = line.firstIndex(of: ":") else { return [] }
        let valuesPart = line[line.index(after: colonIndex)...]
            .trimmingCharacters(in: .whitespaces)
        return valuesPart.components(separatedBy: " ")
            .map { $0.replacingOccurrences(of: "*", with: "") }
            .filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `Cmd+U`
Expected: All 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add AirPrintBridgeDaemon/URFGenerator.swift AirPrintBridgeTests/URFGeneratorTests.swift TestFixtures/
git commit -m "feat: implement URF generation from lpoptions output"
```

---

## Task 4: PPD Stripping

**Files:**
- Create: `AirPrintBridgeDaemon/PPDStripper.swift`
- Create: `AirPrintBridgeTests/PPDStripperTests.swift`
- Create: `TestFixtures/sample_ppd_zebra.ppd`

- [ ] **Step 1: Create test fixture — sample PPD file**

```ppd
// TestFixtures/sample_ppd_zebra.ppd
*PPD-Adobe: "4.3"
*FormatVersion: "4.3"
*FileVersion: "1.0"
*LanguageVersion: English
*Manufacturer: "Zebra"
*ModelName: "Zebra ZPL Label Printer"
*NickName: "Zebra ZPL Label Printer"

*OpenUI *PageSize/Media Size: PickOne
*DefaultPageSize: w288h432
*PageSize w288h432/4x6: "<</PageSize[288 432]/ImagingBBox null>>setpagedevice"
*PageSize w162h288/2.25x4: "<</PageSize[162 288]/ImagingBBox null>>setpagedevice"
*PageSize w288h576/4x8: "<</PageSize[288 576]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageSize

*OpenUI *PageRegion: PickOne
*DefaultPageRegion: w288h432
*PageRegion w288h432/4x6: "<</PageSize[288 432]/ImagingBBox null>>setpagedevice"
*PageRegion w162h288/2.25x4: "<</PageSize[162 288]/ImagingBBox null>>setpagedevice"
*CloseUI: *PageRegion

*DefaultImageableArea: w288h432
*ImageableArea w288h432/4x6: "0 0 288 432"
*ImageableArea w162h288/2.25x4: "0 0 162 288"

*DefaultPaperDimension: w288h432
*PaperDimension w288h432/4x6: "288 432"
*PaperDimension w162h288/2.25x4: "162 288"

*CustomPageSize True: "pop pop pop <</PageSize[5 -2 roll]/ImagingBBox null>>setpagedevice"
*ParamCustomPageSize Width: 1 points 36 1296
*ParamCustomPageSize Height: 2 points 36 1296

*OpenUI *ColorModel/Color Mode: PickOne
*DefaultColorModel: Gray
*ColorModel Gray/Grayscale: "<</cupsColorSpace 0>>setpagedevice"
*CloseUI: *ColorModel
```

- [ ] **Step 2: Write failing tests for PPD stripping**

```swift
// AirPrintBridgeTests/PPDStripperTests.swift
import XCTest
@testable import AirPrintBridgeDaemon

final class PPDStripperTests: XCTestCase {
    func testStripsToSinglePageSize() {
        let input = loadFixture("sample_ppd_zebra", ext: "ppd")
        let result = PPDStripper.strip(ppd: input, widthPoints: 283, heightPoints: 113, sizeLabel: "100x40")

        // Should contain only our custom size, not the originals
        XCTAssertTrue(result.contains("*PageSize w283h113/100x40:"))
        XCTAssertFalse(result.contains("w288h432"))
        XCTAssertFalse(result.contains("w162h288"))
    }

    func testUpdatesDefaults() {
        let input = loadFixture("sample_ppd_zebra", ext: "ppd")
        let result = PPDStripper.strip(ppd: input, widthPoints: 283, heightPoints: 113, sizeLabel: "100x40")

        XCTAssertTrue(result.contains("*DefaultPageSize: w283h113"))
        XCTAssertTrue(result.contains("*DefaultPageRegion: w283h113"))
        XCTAssertTrue(result.contains("*DefaultImageableArea: w283h113"))
        XCTAssertTrue(result.contains("*DefaultPaperDimension: w283h113"))
    }

    func testDisablesCustomPageSize() {
        let input = loadFixture("sample_ppd_zebra", ext: "ppd")
        let result = PPDStripper.strip(ppd: input, widthPoints: 283, heightPoints: 113, sizeLabel: "100x40")

        XCTAssertTrue(result.contains("*CustomPageSize False:"))
        XCTAssertFalse(result.contains("*CustomPageSize True:"))
        XCTAssertFalse(result.contains("*ParamCustomPageSize"))
    }

    func testPreservesNonPageSizeContent() {
        let input = loadFixture("sample_ppd_zebra", ext: "ppd")
        let result = PPDStripper.strip(ppd: input, widthPoints: 283, heightPoints: 113, sizeLabel: "100x40")

        XCTAssertTrue(result.contains("*Manufacturer: \"Zebra\""))
        XCTAssertTrue(result.contains("*OpenUI *ColorModel"))
        XCTAssertTrue(result.contains("*ColorModel Gray/Grayscale:"))
    }

    func testImageableAreaAndPaperDimension() {
        let input = loadFixture("sample_ppd_zebra", ext: "ppd")
        let result = PPDStripper.strip(ppd: input, widthPoints: 283, heightPoints: 113, sizeLabel: "100x40")

        XCTAssertTrue(result.contains("*ImageableArea w283h113/100x40: \"0 0 283 113\""))
        XCTAssertTrue(result.contains("*PaperDimension w283h113/100x40: \"283 113\""))
    }

    private func loadFixture(_ name: String, ext: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: ext)!
        return try! String(contentsOf: url)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `Cmd+U`
Expected: Compilation error — `PPDStripper` not defined.

- [ ] **Step 4: Implement PPDStripper**

```swift
// AirPrintBridgeDaemon/PPDStripper.swift
import Foundation

enum PPDStripper {
    /// Transforms PPD content to contain only a single paper size.
    /// Pure function: String in, String out. No filesystem access.
    static func strip(ppd: String, widthPoints: Int, heightPoints: Int, sizeLabel: String) -> String {
        let w = widthPoints
        let h = heightPoints
        let key = "w\(w)h\(h)"

        var output: [String] = []
        var inPageSize = false
        var inPageRegion = false
        var printedPageSize = false
        var printedPageRegion = false
        var printedImageable = false
        var printedPaperDim = false

        for line in ppd.components(separatedBy: "\n") {
            // Track sections
            if line.hasPrefix("*OpenUI *PageSize") {
                inPageSize = true; output.append(line); continue
            }
            if line.hasPrefix("*CloseUI: *PageSize") {
                if inPageSize, !printedPageSize {
                    output.append("*PageSize \(key)/\(sizeLabel): \"<</PageSize[\(w) \(h)]/ImagingBBox null>>setpagedevice\"")
                }
                inPageSize = false; printedPageSize = false; output.append(line); continue
            }
            if line.hasPrefix("*OpenUI *PageRegion") {
                inPageRegion = true; output.append(line); continue
            }
            if line.hasPrefix("*CloseUI: *PageRegion") {
                if inPageRegion, !printedPageRegion {
                    output.append("*PageRegion \(key)/\(sizeLabel): \"<</PageSize[\(w) \(h)]/ImagingBBox null>>setpagedevice\"")
                }
                inPageRegion = false; printedPageRegion = false; output.append(line); continue
            }

            // Replace PageSize entries
            if inPageSize, line.hasPrefix("*PageSize ") {
                if !printedPageSize {
                    output.append("*PageSize \(key)/\(sizeLabel): \"<</PageSize[\(w) \(h)]/ImagingBBox null>>setpagedevice\"")
                    printedPageSize = true
                }
                continue
            }

            // Replace PageRegion entries
            if inPageRegion, line.hasPrefix("*PageRegion ") {
                if !printedPageRegion {
                    output.append("*PageRegion \(key)/\(sizeLabel): \"<</PageSize[\(w) \(h)]/ImagingBBox null>>setpagedevice\"")
                    printedPageRegion = true
                }
                continue
            }

            // Replace ImageableArea entries (not Default)
            if line.hasPrefix("*ImageableArea "), !line.hasPrefix("*DefaultImageableArea") {
                if !printedImageable {
                    output.append("*ImageableArea \(key)/\(sizeLabel): \"0 0 \(w) \(h)\"")
                    printedImageable = true
                }
                continue
            }

            // Replace PaperDimension entries (not Default)
            if line.hasPrefix("*PaperDimension "), !line.hasPrefix("*DefaultPaperDimension") {
                if !printedPaperDim {
                    output.append("*PaperDimension \(key)/\(sizeLabel): \"\(w) \(h)\"")
                    printedPaperDim = true
                }
                continue
            }

            // Update defaults
            if line.hasPrefix("*DefaultPageSize:") {
                output.append("*DefaultPageSize: \(key)"); continue
            }
            if line.hasPrefix("*DefaultPageRegion:") {
                output.append("*DefaultPageRegion: \(key)"); continue
            }
            if line.hasPrefix("*DefaultImageableArea:") {
                output.append("*DefaultImageableArea: \(key)"); continue
            }
            if line.hasPrefix("*DefaultPaperDimension:") {
                output.append("*DefaultPaperDimension: \(key)"); continue
            }

            // Disable CustomPageSize
            if line.hasPrefix("*CustomPageSize True:") {
                output.append("*CustomPageSize False: \"pop pop pop <</PageSize[5 -2 roll]/ImagingBBox null>>setpagedevice\"")
                continue
            }

            // Remove ParamCustomPageSize
            if line.hasPrefix("*ParamCustomPageSize ") { continue }

            // Keep everything else
            output.append(line)
        }

        return output.joined(separator: "\n")
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `Cmd+U`
Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add AirPrintBridgeDaemon/PPDStripper.swift AirPrintBridgeTests/PPDStripperTests.swift TestFixtures/sample_ppd_zebra.ppd
git commit -m "feat: implement PPD stripping to single paper size"
```

---

## Task 5: TXT Record Builder

**Files:**
- Create: `AirPrintBridgeDaemon/TXTRecordBuilder.swift`
- Create: `AirPrintBridgeTests/TXTRecordBuilderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// AirPrintBridgeTests/TXTRecordBuilderTests.swift
import XCTest
@testable import AirPrintBridgeDaemon

final class TXTRecordBuilderTests: XCTestCase {
    func testBuildsTXTRecords() {
        let records = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: URFResult(urf: "V1.4,W8", hasColor: false, hasDuplex: false)
        )

        XCTAssertTrue(records.contains("txtvers=1"))
        XCTAssertTrue(records.contains("rp=printers/Zebra_DHL"))
        XCTAssertTrue(records.contains("ty=Zebra ZPL Label Printer"))
        XCTAssertTrue(records.contains("product=(Zebra ZPL Label Printer)"))
        XCTAssertTrue(records.contains("note=Magazijn via MacMini"))
        XCTAssertTrue(records.contains("pdl=application/pdf,image/jpeg,image/urf"))
        XCTAssertTrue(records.contains("URF=V1.4,W8"))
        XCTAssertTrue(records.contains("Color=F"))
        XCTAssertTrue(records.contains("Duplex=F"))
    }

    func testColorAndDuplexFlags() {
        let records = TXTRecordBuilder.build(
            printerName: "HP_Color",
            makeAndModel: "HP Color LaserJet",
            location: "",
            hostname: "iMac",
            urf: URFResult(urf: "V1.4,SRGB24,DM2", hasColor: true, hasDuplex: true)
        )

        XCTAssertTrue(records.contains("Color=T"))
        XCTAssertTrue(records.contains("Duplex=T"))
    }

    func testEmptyLocationUsesHostnameOnly() {
        let records = TXTRecordBuilder.build(
            printerName: "Test",
            makeAndModel: "Test Printer",
            location: "",
            hostname: "Mac",
            urf: URFResult(urf: "none", hasColor: false, hasDuplex: false)
        )

        XCTAssertTrue(records.contains("note= via Mac"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Cmd+U`
Expected: Compilation error — `TXTRecordBuilder` not defined.

- [ ] **Step 3: Implement TXTRecordBuilder**

```swift
// AirPrintBridgeDaemon/TXTRecordBuilder.swift
import Foundation

enum TXTRecordBuilder {
    static func build(
        printerName: String,
        makeAndModel: String,
        location: String,
        hostname: String,
        urf: URFResult
    ) -> [String] {
        [
            "txtvers=1",
            "qtotal=1",
            "rp=printers/\(printerName)",
            "ty=\(makeAndModel)",
            "product=(\(makeAndModel))",
            "note=\(location) via \(hostname)",
            "pdl=application/pdf,image/jpeg,image/urf",
            "URF=\(urf.urf)",
            "Color=\(urf.hasColor ? "T" : "F")",
            "Duplex=\(urf.hasDuplex ? "T" : "F")",
        ]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Cmd+U`
Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add AirPrintBridgeDaemon/TXTRecordBuilder.swift AirPrintBridgeTests/TXTRecordBuilderTests.swift
git commit -m "feat: implement AirPrint TXT record builder"
```

---

## Task 6: Shell Command Wrapper

**Files:**
- Create: `AirPrintBridgeDaemon/ShellCommand.swift`

- [ ] **Step 1: Implement ShellCommand**

This is a thin wrapper — no unit tests needed (it wraps `Process`, which is a system API). It will be tested via integration tests.

```swift
// AirPrintBridgeDaemon/ShellCommand.swift
import Foundation

enum ShellCommand {
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        var success: Bool { exitCode == 0 }
    }

    @discardableResult
    static func run(_ command: String, sudo: Bool = false) -> Result {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", sudo ? "sudo \(command)" : command]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return Result(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    /// Run a long-lived background process (dns-sd). Returns the Process handle.
    static func runBackground(_ command: String) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        do {
            try process.run()
            return process
        } catch {
            return nil
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridgeDaemon/ShellCommand.swift
git commit -m "feat: add shell command execution wrapper"
```

---

## Task 7: Config Reader & Status Writer (Daemon side)

**Files:**
- Create: `AirPrintBridgeDaemon/ConfigReader.swift`
- Create: `AirPrintBridgeDaemon/StatusWriter.swift`
- Create: `AirPrintBridgeTests/ConfigReaderTests.swift`
- Create: `AirPrintBridgeTests/StatusReaderTests.swift`

- [ ] **Step 1: Write failing test for ConfigReader**

```swift
// AirPrintBridgeTests/ConfigReaderTests.swift
import XCTest
@testable import AirPrintBridgeDaemon

final class ConfigReaderTests: XCTestCase {
    private let testSuiteName = "nl.labelsenmeer.airprint-bridge.test"

    override func tearDown() {
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)
    }

    func testReadsEnabledPrinters() {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        let printersData: [[String: Any]] = [
            ["name": "Zebra_DHL", "widthMm": 100, "heightMm": 40, "enabled": true],
            ["name": "Brother", "widthMm": 210, "heightMm": 297, "enabled": false],
        ]
        defaults.set(try! JSONSerialization.data(withJSONObject: printersData), forKey: "enabledPrinters")

        let config = ConfigReader(suiteName: testSuiteName)
        let printers = config.readPrinters()

        XCTAssertEqual(printers.count, 2)
        XCTAssertEqual(printers[0].name, "Zebra_DHL")
        XCTAssertEqual(printers[0].widthMm, 100)
        XCTAssertTrue(printers[0].enabled)
        XCTAssertFalse(printers[1].enabled)
    }

    func testReadsDefaultPaperSize() {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.set(100, forKey: "defaultPaperWidth")
        defaults.set(40, forKey: "defaultPaperHeight")

        let config = ConfigReader(suiteName: testSuiteName)
        XCTAssertEqual(config.defaultPaperWidth, 100)
        XCTAssertEqual(config.defaultPaperHeight, 40)
    }

    func testEmptyDefaults_returnsEmptyPrinters() {
        let config = ConfigReader(suiteName: testSuiteName)
        let printers = config.readPrinters()
        XCTAssertTrue(printers.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Cmd+U`
Expected: Compilation error — `ConfigReader` not defined.

- [ ] **Step 3: Implement ConfigReader**

```swift
// AirPrintBridgeDaemon/ConfigReader.swift
import Foundation

final class ConfigReader {
    private let defaults: UserDefaults

    var defaultPaperWidth: Int { defaults.integer(forKey: "defaultPaperWidth") }
    var defaultPaperHeight: Int { defaults.integer(forKey: "defaultPaperHeight") }

    init(suiteName: String = AirPrintBridge.suiteName) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func readPrinters() -> [PrinterConfig] {
        guard let data = defaults.data(forKey: "enabledPrinters") else { return [] }
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return array.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let width = dict["widthMm"] as? Int,
                  let height = dict["heightMm"] as? Int,
                  let enabled = dict["enabled"] as? Bool
            else { return nil }
            return PrinterConfig(name: name, widthMm: width, heightMm: height, enabled: enabled)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `Cmd+U`
Expected: All 3 tests PASS.

- [ ] **Step 5: Implement StatusWriter**

```swift
// AirPrintBridgeDaemon/StatusWriter.swift
import Foundation

struct DaemonStatus: Codable {
    let running: Bool
    let printers: [PrinterStatus]
    let lastUpdated: Date

    struct PrinterStatus: Codable {
        let name: String
        let registered: Bool
        let error: String?
    }
}

enum StatusWriter {
    static func write(_ status: DaemonStatus, to path: String = AirPrintBridge.statusFilePath) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(status) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
```

- [ ] **Step 6: Write failing test for StatusReader (app side)**

```swift
// AirPrintBridgeTests/StatusReaderTests.swift
import XCTest
@testable import AirPrintBridge

final class StatusReaderTests: XCTestCase {
    private let testPath = NSTemporaryDirectory() + "airprint-bridge-test-status.json"

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testPath)
    }

    func testReadsValidStatus() {
        let json = """
        {
          "running": true,
          "printers": [
            {"name": "Zebra_DHL", "registered": true, "error": null}
          ],
          "lastUpdated": "2026-04-07T10:00:00Z"
        }
        """
        FileManager.default.createFile(atPath: testPath, contents: json.data(using: .utf8))

        let status = StatusReader.read(from: testPath)
        XCTAssertNotNil(status)
        XCTAssertTrue(status!.running)
        XCTAssertEqual(status!.printers.count, 1)
        XCTAssertEqual(status!.printers[0].name, "Zebra_DHL")
    }

    func testMissingFile_returnsNil() {
        let status = StatusReader.read(from: "/tmp/nonexistent-airprint-status.json")
        XCTAssertNil(status)
    }
}
```

- [ ] **Step 7: Implement StatusReader (app side)**

```swift
// AirPrintBridge/Services/StatusReader.swift
import Foundation

enum StatusReader {
    static func read(from path: String = AirPrintBridge.statusFilePath) -> DaemonStatus? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DaemonStatus.self, from: data)
    }
}
```

- [ ] **Step 8: Run all tests**

Run: `Cmd+U`
Expected: All tests PASS.

- [ ] **Step 9: Commit**

```bash
git add AirPrintBridgeDaemon/ConfigReader.swift AirPrintBridgeDaemon/StatusWriter.swift AirPrintBridge/Services/StatusReader.swift AirPrintBridgeTests/ConfigReaderTests.swift AirPrintBridgeTests/StatusReaderTests.swift
git commit -m "feat: add config reader, status writer, and status reader"
```

---

## Task 8: CUPS Manager & Firewall Manager

**Files:**
- Create: `AirPrintBridgeDaemon/CUPSManager.swift`
- Create: `AirPrintBridgeDaemon/FirewallManager.swift`

> **Note:** These modules call system commands (`lpstat`, `lpadmin`, `cupsd`, `socketfilterfw`) and modify system files. They are not unit-testable in isolation — they will be verified via integration/manual testing. The testable logic (PPD stripping, URF generation) has already been extracted into pure functions.

- [ ] **Step 1: Implement CUPSManager**

```swift
// AirPrintBridgeDaemon/CUPSManager.swift
import Foundation

enum CUPSManager {
    /// Check and fix CUPS permissions: ensure `Allow @LOCAL` in cupsd.conf
    /// and all shared printers allow all users.
    @discardableResult
    static func ensurePermissions() -> Bool {
        let cupsConf = AirPrintBridge.cupsConfigPath

        // Check if Allow @LOCAL exists
        let result = ShellCommand.run("cat \(cupsConf)")
        guard result.success else {
            log("Failed to read \(cupsConf)")
            return false
        }

        if !result.stdout.contains("Allow @LOCAL") {
            log("CUPS missing Allow @LOCAL — fixing...")

            // Backup if no backup exists
            ShellCommand.run("[ ! -f \(cupsConf).bak ] && cp \(cupsConf) \(cupsConf).bak")

            // Insert Allow @LOCAL after Order allow,deny in <Location />
            let sedCmd = "sed -i '' '/<Location \\/>/,/<\\/Location>/ s/Order allow,deny/Order allow,deny\\n  Allow @LOCAL/' \(cupsConf)"
            ShellCommand.run(sedCmd)

            // Validate and restart
            let validate = ShellCommand.run("cupsd -t")
            if validate.success {
                restartCUPS()
                log("CUPS permissions fixed")
            } else {
                log("CUPS config invalid after fix — reverting")
                revertConfig()
                return false
            }
        }

        // Ensure shared printers allow all users
        let printers = ShellCommand.run("lpstat -p | awk '{print $2}'")
        for printerName in printers.stdout.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
            let opts = ShellCommand.run("lpoptions -p \(printerName)")
            if opts.stdout.contains("printer-is-shared=true") {
                let detail = ShellCommand.run("lpstat -l -p \(printerName)")
                if !detail.stdout.lowercased().contains("allowed users: all") {
                    ShellCommand.run("lpadmin -p \(printerName) -u allow:all")
                    log("Set allow:all on \(printerName)")
                }
            }
        }

        return true
    }

    /// Strip PPD for a printer to a single paper size using PPDStripper.
    static func stripPPD(printerName: String, widthPoints: Int, heightPoints: Int, sizeLabel: String) -> Bool {
        let ppdPath = "\(AirPrintBridge.ppdBasePath)/\(printerName).ppd"

        let read = ShellCommand.run("cat \(ppdPath)")
        guard read.success else {
            log("PPD not found for \(printerName)")
            return false
        }

        // Backup original if not already backed up
        ShellCommand.run("[ ! -f \(ppdPath).original ] && cp \(ppdPath) \(ppdPath).original")

        let stripped = PPDStripper.strip(
            ppd: read.stdout,
            widthPoints: widthPoints,
            heightPoints: heightPoints,
            sizeLabel: sizeLabel
        )

        // Write stripped PPD
        let tmpPath = "\(ppdPath).tmp"
        guard FileManager.default.createFile(atPath: tmpPath, contents: stripped.data(using: .utf8)) else {
            log("Failed to write stripped PPD for \(printerName)")
            return false
        }
        ShellCommand.run("mv \(tmpPath) \(ppdPath)")

        restartCUPS()
        log("PPD stripped for \(printerName) to \(sizeLabel)")
        return true
    }

    /// Restore original PPD from backup.
    static func restorePPD(printerName: String) {
        let ppdPath = "\(AirPrintBridge.ppdBasePath)/\(printerName).ppd"
        let originalPath = "\(ppdPath).original"

        let check = ShellCommand.run("[ -f \(originalPath) ] && echo exists")
        if check.stdout.contains("exists") {
            ShellCommand.run("cp \(originalPath) \(ppdPath)")
            restartCUPS()
            log("Restored original PPD for \(printerName)")
        }
    }

    /// Revert CUPS config from backup.
    static func revertConfig() {
        let cupsConf = AirPrintBridge.cupsConfigPath
        let check = ShellCommand.run("[ -f \(cupsConf).bak ] && echo exists")
        if check.stdout.contains("exists") {
            ShellCommand.run("cp \(cupsConf).bak \(cupsConf)")
            restartCUPS()
            log("CUPS config reverted from backup")
        }
    }

    static func restartCUPS() {
        ShellCommand.run("launchctl stop org.cups.cupsd")
        ShellCommand.run("launchctl start org.cups.cupsd")
    }

    private static func log(_ message: String) {
        print("[CUPSManager] \(message)")
    }
}
```

- [ ] **Step 2: Implement FirewallManager**

```swift
// AirPrintBridgeDaemon/FirewallManager.swift
import Foundation

enum FirewallManager {
    static func ensureCUPSAllowed() {
        let fwState = ShellCommand.run("/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate")

        guard fwState.stdout.lowercased().contains("enabled") else {
            log("Firewall disabled — skipping")
            return
        }

        log("Firewall enabled — checking CUPS access")

        let cupsBin = ShellCommand.run("which cupsd").stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cupsPath = cupsBin.isEmpty ? "/usr/sbin/cupsd" : cupsBin

        let listed = ShellCommand.run("/usr/libexec/ApplicationFirewall/socketfilterfw --listapps")
        if !listed.stdout.contains(cupsPath) {
            ShellCommand.run("/usr/libexec/ApplicationFirewall/socketfilterfw --add \(cupsPath)")
            ShellCommand.run("/usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp \(cupsPath)")
            log("Allowed \(cupsPath) in firewall")
        } else {
            log("CUPS already allowed in firewall")
        }
    }

    private static func log(_ message: String) {
        print("[FirewallManager] \(message)")
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add AirPrintBridgeDaemon/CUPSManager.swift AirPrintBridgeDaemon/FirewallManager.swift
git commit -m "feat: add CUPS permission manager and firewall manager"
```

---

## Task 9: dns-sd Registration Manager

**Files:**
- Create: `AirPrintBridgeDaemon/DNSSDRegistrar.swift`

- [ ] **Step 1: Implement DNSSDRegistrar**

```swift
// AirPrintBridgeDaemon/DNSSDRegistrar.swift
import Foundation

final class DNSSDRegistrar {
    private var processes: [String: Process] = [:]

    /// Register a printer for AirPrint via dns-sd.
    func register(
        printerName: String,
        description: String,
        port: Int,
        txtRecords: [String]
    ) -> Bool {
        // Kill existing registration for this printer
        unregister(printerName: printerName)

        let txtArgs = txtRecords.map { "\"\($0)\"" }.joined(separator: " ")
        let command = "dns-sd -R \"\(description)\" \"\(AirPrintBridge.service)\" \"\(AirPrintBridge.domain)\" \(port) \(txtArgs)"

        guard let process = ShellCommand.runBackground(command) else {
            print("[DNSSDRegistrar] Failed to start dns-sd for \(printerName)")
            return false
        }

        processes[printerName] = process
        print("[DNSSDRegistrar] Registered \(printerName) (PID: \(process.processIdentifier))")
        return true
    }

    /// Unregister a single printer.
    func unregister(printerName: String) {
        guard let process = processes.removeValue(forKey: printerName) else { return }
        if process.isRunning {
            process.terminate()
            print("[DNSSDRegistrar] Unregistered \(printerName)")
        }
    }

    /// Unregister all printers.
    func unregisterAll() {
        for (name, process) in processes {
            if process.isRunning {
                process.terminate()
            }
            print("[DNSSDRegistrar] Unregistered \(name)")
        }
        processes.removeAll()
    }

    /// List currently registered printer names.
    var registeredPrinters: [String] {
        Array(processes.keys)
    }

    deinit {
        unregisterAll()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridgeDaemon/DNSSDRegistrar.swift
git commit -m "feat: add dns-sd registration manager"
```

---

## Task 10: Daemon Main — Orchestration, Signal Handling, PID File

**Files:**
- Modify: `AirPrintBridgeDaemon/main.swift`

- [ ] **Step 1: Implement full daemon entry point**

```swift
// AirPrintBridgeDaemon/main.swift
import Foundation

// MARK: - State

let configReader = ConfigReader()
let registrar = DNSSDRegistrar()
var isRunning = true

// MARK: - PID File

func writePIDFile() {
    let pid = ProcessInfo.processInfo.processIdentifier
    try? "\(pid)".write(toFile: AirPrintBridge.pidFilePath, atomically: true, encoding: .utf8)
    print("[Daemon] PID \(pid) written to \(AirPrintBridge.pidFilePath)")
}

func removePIDFile() {
    try? FileManager.default.removeItem(atPath: AirPrintBridge.pidFilePath)
}

// MARK: - Printer Resolution

func resolveAndRegister(printer: PrinterConfig) -> DaemonStatus.PrinterStatus {
    let name = printer.name

    // Get lpoptions for URF generation
    let lpoptionsResult = ShellCommand.run("lpoptions -l -p \(name)")
    let urf = URFGenerator.generate(from: lpoptionsResult.stdout)

    // Get printer description
    let descResult = ShellCommand.run("lpstat -l -p \(name)")
    let description = descResult.stdout
        .components(separatedBy: "\n")
        .first { $0.contains("Description:") }
        .flatMap { $0.components(separatedBy: "Description:").last?.trimmingCharacters(in: .whitespaces) }
        ?? name

    // Get location
    let location = descResult.stdout
        .components(separatedBy: "\n")
        .first { $0.contains("Location:") }
        .flatMap { $0.components(separatedBy: "Location:").last?.trimmingCharacters(in: .whitespaces) }
        ?? ""

    // Get make and model
    let optsResult = ShellCommand.run("lpoptions -p \(name)")
    let makeModel: String = {
        let opts = optsResult.stdout
        if let range = opts.range(of: "printer-make-and-model='") {
            let start = range.upperBound
            if let end = opts[start...].firstIndex(of: "'") {
                return String(opts[start..<end])
            }
        }
        return name
    }()

    let hostname = ProcessInfo.processInfo.hostName
        .components(separatedBy: ".").first ?? "Mac"

    // Strip PPD
    let ppdOk = CUPSManager.stripPPD(
        printerName: name,
        widthPoints: printer.widthPoints,
        heightPoints: printer.heightPoints,
        sizeLabel: printer.sizeLabel
    )

    if !ppdOk {
        return DaemonStatus.PrinterStatus(name: name, registered: false, error: "PPD configuratie mislukt")
    }

    // Build TXT records
    let txtRecords = TXTRecordBuilder.build(
        printerName: name,
        makeAndModel: makeModel,
        location: location,
        hostname: hostname,
        urf: urf
    )

    // Register dns-sd
    let displayName = "\(description) @ \(hostname)"
    let registered = registrar.register(
        printerName: name,
        description: displayName,
        port: 631,
        txtRecords: txtRecords
    )

    return DaemonStatus.PrinterStatus(
        name: name,
        registered: registered,
        error: registered ? nil : "dns-sd registratie mislukt"
    )
}

// MARK: - Setup

func setup() {
    print("[Daemon] Running setup...")

    // Tear down existing registrations
    registrar.unregisterAll()

    // System checks
    CUPSManager.ensurePermissions()
    FirewallManager.ensureCUPSAllowed()

    // Read config and register enabled printers
    let printers = configReader.readPrinters()
    let enabledPrinters = printers.filter(\.enabled)

    print("[Daemon] Found \(enabledPrinters.count) enabled printer(s)")

    var printerStatuses: [DaemonStatus.PrinterStatus] = []
    for printer in enabledPrinters {
        let status = resolveAndRegister(printer: printer)
        printerStatuses.append(status)
    }

    // Write status
    let status = DaemonStatus(
        running: true,
        printers: printerStatuses,
        lastUpdated: Date()
    )
    StatusWriter.write(status)

    print("[Daemon] Setup complete — \(printerStatuses.filter(\.registered).count) printer(s) registered")
}

// MARK: - Cleanup

func cleanup() {
    print("[Daemon] Cleaning up...")
    registrar.unregisterAll()

    // Restore all PPDs
    let printers = configReader.readPrinters()
    for printer in printers {
        CUPSManager.restorePPD(printerName: printer.name)
    }

    let status = DaemonStatus(running: false, printers: [], lastUpdated: Date())
    StatusWriter.write(status)

    removePIDFile()
    print("[Daemon] Cleanup complete")
}

// MARK: - Signal Handling

signal(SIGHUP) { _ in
    print("[Daemon] Received SIGHUP — reloading config...")
    setup()
}

signal(SIGTERM) { _ in
    print("[Daemon] Received SIGTERM — shutting down...")
    cleanup()
    exit(0)
}

signal(SIGINT) { _ in
    print("[Daemon] Received SIGINT — shutting down...")
    cleanup()
    exit(0)
}

// MARK: - Main

print("[Daemon] AirPrint Bridge Daemon starting...")
writePIDFile()
setup()
dispatchMain()
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridgeDaemon/main.swift
git commit -m "feat: implement daemon orchestration with signal handling"
```

---

## Task 11: Printer Discovery (App Side)

**Files:**
- Create: `AirPrintBridge/Models/PrinterDiscovery.swift`
- Create: `AirPrintBridgeTests/PrinterDiscoveryTests.swift`
- Create: `TestFixtures/sample_lpstat_output.txt`

- [ ] **Step 1: Create test fixture — lpstat output**

```
// TestFixtures/sample_lpstat_output.txt
printer Zebra_DHL is idle.  enabled since Mon 07 Apr 2026 10:00:00 AM CEST
	Description: Zebra DHL
	Location: Magazijn
	Connection: direct
	Interface: /etc/cups/ppd/Zebra_DHL.ppd
	Make and Model: Zebra ZPL Label Printer
	Accepting Jobs: yes
	Shared: yes
printer Brother_Kantoor is idle.  enabled since Mon 07 Apr 2026 10:00:00 AM CEST
	Description: Brother Kantoor
	Location: Kantoor
	Connection: direct
	Interface: /etc/cups/ppd/Brother_Kantoor.ppd
	Make and Model: Brother HL-L2350DW
	Accepting Jobs: yes
	Shared: yes
printer HP_Private is idle.  enabled since Mon 07 Apr 2026 10:00:00 AM CEST
	Description: HP Private
	Location: 
	Connection: direct
	Interface: /etc/cups/ppd/HP_Private.ppd
	Make and Model: HP LaserJet
	Accepting Jobs: yes
	Shared: no
```

- [ ] **Step 2: Write failing tests**

```swift
// AirPrintBridgeTests/PrinterDiscoveryTests.swift
import XCTest
@testable import AirPrintBridge

final class PrinterDiscoveryTests: XCTestCase {
    func testParsesSharedPrinters() {
        let input = loadFixture("sample_lpstat_output")
        let printers = PrinterDiscovery.parse(lpstatOutput: input)

        // HP_Private is not shared, so only 2 printers
        XCTAssertEqual(printers.count, 2)
        XCTAssertEqual(printers[0].name, "Zebra_DHL")
        XCTAssertEqual(printers[0].model, "Zebra ZPL Label Printer")
        XCTAssertEqual(printers[0].location, "Magazijn")
        XCTAssertEqual(printers[1].name, "Brother_Kantoor")
        XCTAssertEqual(printers[1].model, "Brother HL-L2350DW")
    }

    func testEmptyInput() {
        let printers = PrinterDiscovery.parse(lpstatOutput: "")
        XCTAssertTrue(printers.isEmpty)
    }

    private func loadFixture(_ name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: "txt")!
        return try! String(contentsOf: url)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `Cmd+U`
Expected: Compilation error — `PrinterDiscovery` not defined.

- [ ] **Step 4: Implement PrinterDiscovery**

```swift
// AirPrintBridge/Models/PrinterDiscovery.swift
import Foundation

struct DiscoveredPrinter: Identifiable {
    let name: String
    let model: String
    let location: String

    var id: String { name }
}

enum PrinterDiscovery {
    /// Parse `lpstat -l -p` output to find shared printers.
    static func parse(lpstatOutput: String) -> [DiscoveredPrinter] {
        var printers: [DiscoveredPrinter] = []
        var currentName: String?
        var currentModel = ""
        var currentLocation = ""
        var currentShared = false

        func flushCurrent() {
            if let name = currentName, currentShared {
                printers.append(DiscoveredPrinter(name: name, model: currentModel, location: currentLocation))
            }
            currentName = nil
            currentModel = ""
            currentLocation = ""
            currentShared = false
        }

        for line in lpstatOutput.components(separatedBy: "\n") {
            if line.hasPrefix("printer ") {
                flushCurrent()
                // "printer Zebra_DHL is idle. ..."
                let parts = line.components(separatedBy: " ")
                if parts.count >= 2 {
                    currentName = parts[1]
                }
            } else if line.contains("Make and Model:") {
                currentModel = line.components(separatedBy: "Make and Model:").last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
            } else if line.contains("Location:") {
                currentLocation = line.components(separatedBy: "Location:").last?
                    .trimmingCharacters(in: .whitespaces) ?? ""
            } else if line.contains("Shared:") {
                currentShared = line.lowercased().contains("yes")
            }
        }
        flushCurrent()

        return printers
    }

    /// Live discovery using `lpstat -l -p`.
    static func discover() -> [DiscoveredPrinter] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-l", "-p"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return parse(lpstatOutput: output)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `Cmd+U`
Expected: All 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add AirPrintBridge/Models/PrinterDiscovery.swift AirPrintBridgeTests/PrinterDiscoveryTests.swift TestFixtures/sample_lpstat_output.txt
git commit -m "feat: add printer discovery with lpstat parsing"
```

---

## Task 12: BridgeConfig — App Config Model

**Files:**
- Create: `AirPrintBridge/Models/BridgeConfig.swift`

- [ ] **Step 1: Implement BridgeConfig**

```swift
// AirPrintBridge/Models/BridgeConfig.swift
import Foundation
import Combine

final class BridgeConfig: ObservableObject {
    private let defaults: UserDefaults

    @Published var defaultPaperWidth: Int {
        didSet { defaults.set(defaultPaperWidth, forKey: "defaultPaperWidth") }
    }
    @Published var defaultPaperHeight: Int {
        didSet { defaults.set(defaultPaperHeight, forKey: "defaultPaperHeight") }
    }
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }
    @Published var printers: [PrinterConfig] {
        didSet { savePrinters() }
    }

    init(suiteName: String = AirPrintBridge.suiteName) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = defaults

        self.defaultPaperWidth = defaults.object(forKey: "defaultPaperWidth") as? Int ?? 100
        self.defaultPaperHeight = defaults.object(forKey: "defaultPaperHeight") as? Int ?? 40
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        self.printers = []

        loadPrinters()
    }

    func loadPrinters() {
        guard let data = defaults.data(forKey: "enabledPrinters"),
              let array = try? JSONDecoder().decode([PrinterConfig].self, from: data)
        else {
            printers = []
            return
        }
        printers = array
    }

    /// Sync discovered printers with saved config.
    /// New printers get default paper size. Existing printers keep their settings.
    func syncWithDiscovered(_ discovered: [DiscoveredPrinter]) {
        let existingByName = Dictionary(uniqueKeysWithValues: printers.map { ($0.name, $0) })

        printers = discovered.map { disc in
            if let existing = existingByName[disc.name] {
                return existing
            }
            return PrinterConfig(
                name: disc.name,
                widthMm: defaultPaperWidth,
                heightMm: defaultPaperHeight,
                enabled: false
            )
        }
    }

    /// Send SIGHUP to daemon to reload config.
    func notifyDaemon() {
        guard let pidString = try? String(contentsOfFile: AirPrintBridge.pidFilePath),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        kill(pid, SIGHUP)
    }

    private func savePrinters() {
        guard let data = try? JSONEncoder().encode(printers) else { return }
        defaults.set(data, forKey: "enabledPrinters")
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridge/Models/BridgeConfig.swift
git commit -m "feat: add BridgeConfig observable model with UserDefaults sync"
```

---

## Task 13: Daemon Manager (SMAppService)

**Files:**
- Create: `AirPrintBridge/Services/DaemonManager.swift`

- [ ] **Step 1: Implement DaemonManager**

```swift
// AirPrintBridge/Services/DaemonManager.swift
import Foundation
import ServiceManagement

final class DaemonManager: ObservableObject {
    private let service: SMAppService

    var status: SMAppService.Status {
        service.status
    }

    var isRegistered: Bool {
        status == .enabled
    }

    var statusDescription: String {
        switch status {
        case .notRegistered: return "Niet geregistreerd"
        case .enabled: return "Actief"
        case .requiresApproval: return "Wacht op goedkeuring"
        case .notFound: return "Niet gevonden"
        @unknown default: return "Onbekend"
        }
    }

    init() {
        self.service = SMAppService.daemon(plistName: "\(AirPrintBridge.daemonLabel).plist")
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridge/Services/DaemonManager.swift
git commit -m "feat: add DaemonManager with SMAppService wrapper"
```

---

## Task 14: Popover View (Menu Bar)

**Files:**
- Create: `AirPrintBridge/Views/PopoverView.swift`

- [ ] **Step 1: Implement PopoverView**

```swift
// AirPrintBridge/Views/PopoverView.swift
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var config: BridgeConfig
    @State private var daemonStatus: DaemonStatus?
    @State private var discoveredPrinters: [DiscoveredPrinter] = []

    private var isRunning: Bool { daemonStatus?.running ?? false }
    private var enabledCount: Int { config.printers.filter(\.enabled).count }
    private var totalCount: Int { config.printers.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            printerList
            Divider()
            footer
        }
        .padding()
        .frame(width: 320)
        .onAppear { refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AirPrint Bridge")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            Text("\(enabledCount) van \(totalCount) printers gedeeld")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? .green : .red)
                .frame(width: 8, height: 8)
            Text(isRunning ? "Actief" : "Gestopt")
                .font(.caption)
                .foregroundStyle(isRunning ? .green : .red)
        }
    }

    // MARK: - Printer List

    private var printerList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.printers.isEmpty {
                Text("Geen gedeelde printers gevonden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(config.printers.enumerated()), id: \.element.id) { index, printer in
                    printerRow(printer: printer, index: index)
                }
            }
        }
    }

    private func printerRow(printer: PrinterConfig, index: Int) -> some View {
        let discovered = discoveredPrinters.first { $0.name == printer.name }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(printer.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(discovered?.model ?? "Onbekend model") - \(printer.sizeLabel)mm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { printer.enabled },
                set: { newValue in
                    var updated = printer
                    updated.enabled = newValue
                    config.printers[index] = updated
                    config.notifyDaemon()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .opacity(printer.enabled ? 1.0 : 0.6)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Instellingen") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Spacer()
            Button("Vernieuw") { refresh() }
            Button(isRunning ? "Stop" : "Start") {
                toggleDaemon()
            }
        }
    }

    // MARK: - Actions

    private func refresh() {
        discoveredPrinters = PrinterDiscovery.discover()
        config.syncWithDiscovered(discoveredPrinters)
        daemonStatus = StatusReader.read()
    }

    private func toggleDaemon() {
        // Handled via DaemonManager in the app — simplified here
        // The daemon auto-restarts via KeepAlive, so "stop" kills the process
        // and launchd restarts it. For a real stop, unregister the daemon.
        refresh()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridge/Views/PopoverView.swift
git commit -m "feat: implement menu bar popover view"
```

---

## Task 15: Settings Views

**Files:**
- Create: `AirPrintBridge/Views/SettingsGeneralView.swift`
- Create: `AirPrintBridge/Views/SettingsPrintersView.swift`

- [ ] **Step 1: Implement SettingsGeneralView**

```swift
// AirPrintBridge/Views/SettingsGeneralView.swift
import SwiftUI

struct SettingsGeneralView: View {
    @EnvironmentObject private var config: BridgeConfig
    @StateObject private var daemonManager = DaemonManager()
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { daemonManager.isRegistered },
                    set: { newValue in toggleDaemon(enable: newValue) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Start bij opstarten")
                        Text("Draait als achtergrondservice, ook zonder dat iemand is ingelogd")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $config.showMenuBarIcon) {  // works via @Published
                    VStack(alignment: .leading) {
                        Text("Toon icoontje in menubalk")
                        Text("Als uitgeschakeld, open Instellingen via Spotlight of de app opnieuw")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Standaard papierformaat") {
                HStack {
                    TextField("Breedte", value: $config.defaultPaperWidth, format: .number)
                        .frame(width: 80)
                    Text("x")
                    TextField("Hoogte", value: $config.defaultPaperHeight, format: .number)
                        .frame(width: 80)
                    Text("mm")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }

    private func toggleDaemon(enable: Bool) {
        do {
            if enable {
                try daemonManager.register()
            } else {
                try daemonManager.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Kon de achtergrondservice niet \(enable ? "starten" : "stoppen"): \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Implement SettingsPrintersView**

```swift
// AirPrintBridge/Views/SettingsPrintersView.swift
import SwiftUI

struct SettingsPrintersView: View {
    @EnvironmentObject private var config: BridgeConfig
    @State private var discoveredPrinters: [DiscoveredPrinter] = []

    var body: some View {
        Form {
            if config.printers.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Geen gedeelde printers", systemImage: "printer.slash")
                    } description: {
                        Text("Deel printers via Systeemvoorkeuren > Printers en scanners")
                    }
                }
            } else {
                Section {
                    ForEach(Array(config.printers.enumerated()), id: \.element.id) { index, printer in
                        printerRow(printer: printer, index: index)
                    }
                }
            }

            Section {
                Button("Vernieuw printerlijst") {
                    refresh()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
        .onAppear { refresh() }
    }

    private func printerRow(printer: PrinterConfig, index: Int) -> some View {
        let discovered = discoveredPrinters.first { $0.name == printer.name }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(printer.name)
                        .fontWeight(.medium)
                    Text(discovered?.model ?? "Onbekend model")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("AirPrint", isOn: Binding(
                    get: { printer.enabled },
                    set: { newValue in
                        var updated = printer
                        updated.enabled = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ))
                .toggleStyle(.switch)
            }

            HStack {
                Text("Papierformaat:")
                    .font(.caption)
                TextField("B", value: Binding(
                    get: { printer.widthMm },
                    set: { newValue in
                        var updated = printer
                        updated.widthMm = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ), format: .number)
                .frame(width: 60)
                Text("x")
                    .font(.caption)
                TextField("H", value: Binding(
                    get: { printer.heightMm },
                    set: { newValue in
                        var updated = printer
                        updated.heightMm = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ), format: .number)
                .frame(width: 60)
                Text("mm")
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func refresh() {
        discoveredPrinters = PrinterDiscovery.discover()
        config.syncWithDiscovered(discoveredPrinters)
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add AirPrintBridge/Views/SettingsGeneralView.swift AirPrintBridge/Views/SettingsPrintersView.swift
git commit -m "feat: implement settings views (Algemeen + Printers tabs)"
```

---

## Task 16: App Entry Point — Wire Everything Together

**Files:**
- Modify: `AirPrintBridge/AirPrintBridgeApp.swift`

- [ ] **Step 1: Update AirPrintBridgeApp with full implementation**

```swift
// AirPrintBridge/AirPrintBridgeApp.swift
import SwiftUI

@main
struct AirPrintBridgeApp: App {
    @StateObject private var config = BridgeConfig()

    var body: some Scene {
        MenuBarExtra(
            "AirPrint Bridge",
            systemImage: "printer.fill",
            isInserted: $config.showMenuBarIcon
        ) {
            PopoverView()
                .environmentObject(config)
        }
        .menuBarExtraStyle(.window)

        Settings {
            TabView {
                SettingsGeneralView()
                    .tabItem {
                        Label("Algemeen", systemImage: "gear")
                    }
                SettingsPrintersView()
                    .tabItem {
                        Label("Printers", systemImage: "printer")
                    }
            }
            .environmentObject(config)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `Cmd+B`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridge/AirPrintBridgeApp.swift
git commit -m "feat: wire up app entry point with MenuBarExtra and Settings"
```

---

## Task 17: App Icon & Menu Bar Icon

**Files:**
- Modify: `AirPrintBridge/Assets.xcassets`

- [ ] **Step 1: Add app icon**

Use SF Symbol `printer.fill` for the menu bar icon (already configured in code).

For the app icon (Assets.xcassets → AppIcon):
- Create a simple icon using the Labels en Meer brand colors
- Or use a printer icon as placeholder
- The app icon is needed for Spotlight, but is rarely seen since `LSUIElement = YES`

- [ ] **Step 2: Build and run to verify menu bar icon appears**

Run: `Cmd+R`
Expected: Printer icon appears in menu bar. Clicking shows the popover. Cmd+, opens Settings.

- [ ] **Step 3: Commit**

```bash
git add AirPrintBridge/Assets.xcassets
git commit -m "chore: add app icon and menu bar icon"
```

---

## Task 18: Integration Testing & Manual Verification

**Files:** No new files — this is a verification task.

- [ ] **Step 1: Run all unit tests**

Run: `Cmd+U` or:
```bash
xcodebuild test -scheme AirPrintBridge -destination 'platform=macOS'
```
Expected: All tests PASS (UnitConversion, URFGenerator, PPDStripper, TXTRecordBuilder, ConfigReader, StatusReader, PrinterDiscovery).

- [ ] **Step 2: Verify code signing**

```bash
codesign --verify --deep --strict AirPrintBridge.app
codesign --verify --deep --strict AirPrintBridge.app/Contents/Library/LaunchDaemons/AirPrintBridgeDaemon
```
Expected: Both pass verification.

- [ ] **Step 3: Manual test — full flow**

1. Build and run AirPrintBridge.app
2. Click menu bar icon → popover appears with "Gestopt" status
3. Open Settings (Cmd+,) → Algemeen tab
4. Enable "Start bij opstarten" → admin password prompt appears
5. After entering password, daemon starts → popover shows "Actief"
6. Switch to Printers tab → shared CUPS printers listed
7. Toggle a printer on → daemon receives SIGHUP, registers dns-sd
8. On iOS device on same network: check Settings → Printers → printer should appear
9. Toggle printer off → dns-sd unregistered, PPD restored
10. Disable "Start bij opstarten" → daemon unregistered

- [ ] **Step 4: Test error cases**

1. No shared printers → popover shows "Geen gedeelde printers gevonden"
2. Deny admin password → error alert shown
3. Kill daemon manually (`sudo kill $(cat /var/run/airprint-bridge.pid)`) → launchd restarts it (KeepAlive)

- [ ] **Step 5: Commit final state**

```bash
git add -A
git commit -m "chore: integration testing complete"
```

---

## Summary

| Task | Description | Type | Testable |
|------|-------------|------|----------|
| 1 | Xcode project setup | Scaffold | Build |
| 2 | PrinterConfig + UnitConversion | Models | Unit tests |
| 3 | URF Generation | Daemon logic | Unit tests |
| 4 | PPD Stripping | Daemon logic | Unit tests |
| 5 | TXT Record Builder | Daemon logic | Unit tests |
| 6 | Shell Command Wrapper | Daemon infra | Build |
| 7 | Config Reader + Status Writer/Reader | Config | Unit tests |
| 8 | CUPS Manager + Firewall Manager | Daemon system | Integration |
| 9 | dns-sd Registration Manager | Daemon system | Integration |
| 10 | Daemon main (orchestration + signals) | Daemon entry | Integration |
| 11 | Printer Discovery | App model | Unit tests |
| 12 | BridgeConfig | App model | Build |
| 13 | Daemon Manager (SMAppService) | App service | Build |
| 14 | Popover View | App UI | Manual |
| 15 | Settings Views | App UI | Manual |
| 16 | App Entry Point | App wiring | Manual |
| 17 | App Icon | Assets | Manual |
| 18 | Integration Testing | Verification | All |
