# Fearless Wallet for macOS

A native SwiftUI wallet for macOS 14 Sonoma and later, built for the desktop:
a sidebar window with sortable tables and an inspector, a full menu bar with
keyboard shortcuts, a Settings window, a menu bar extra, Touch ID, and
auto-lock on sleep, screen lock and idle.

It shares the iOS app's open-source native modules in `../Native`
(IrohaCrypto, sr25519, the SSF runtime, extrinsic and keystore code), so a
recovery phrase gives the same addresses on the Mac as on iPhone, Android and
the browser extension.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd macOS
xcodegen
open FearlessMac.xcodeproj
```

Command line:

```bash
macOS/scripts/verify.sh            # package tests + app build, logs under macOS/build/reports
macOS/scripts/verify.sh --ui-tests # also runs the XCUITest launch tests
```

Run the interface alone with sample data (no network, no keys):

```bash
swift run --package-path macOS/Packages/FearlessMacUI FearlessMacDemo
```

## Layout

| Path | What |
| --- | --- |
| `App/` | App target: composition root, Info.plist, entitlements, icon |
| `Packages/WalletCore` | Contract between UI and engine: models and service protocols |
| `Packages/FearlessMacEngine` | Wallet engine over `../Native`: vault, keys, chains, balances, transfers |
| `Packages/FearlessMacUI` | Design system, screens, preview data, demo and snapshot tools |
| `UITests/` | XCUITest launch tests against a throwaway wallet store |
| `docs/` | Architecture, engine notes, UI notes |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the security model and
the rules each part follows.

## Signing

Debug builds are signed to run locally. Touch ID unlock needs the
data-protection keychain, which needs a build signed with the team's
provisioning profile; without it the app offers password unlock only.
