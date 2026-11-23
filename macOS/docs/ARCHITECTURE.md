# Fearless Wallet for macOS: architecture

A native SwiftUI app for macOS 14 Sonoma and later, built from this repository
(`soramitsu/fearless-iOS`, folder `macOS/`). It reuses the iOS app's own
open-source native modules in `Native/` (IrohaCrypto, sr25519, SSF runtime,
extrinsic and keystore code), so one recovery phrase gives the same addresses
on iPhone, Android, the browser extension and the Mac.

## Layout and ownership

```
macOS/
  App/                       Xcode app target: composition root, Info.plist,
                             entitlements, asset catalog (owner: coordinator)
  project.yml                XcodeGen spec -> FearlessMac.xcodeproj (coordinator)
  Packages/
    WalletCore/              Contract: models + service protocols, no deps (coordinator)
    FearlessMacEngine/       WalletEngine: real implementation over Native/ (engine lane)
    FearlessMacUI/           DesignSystem, WalletUI, WalletPreviewSupport,
                             FearlessMacDemo (UI lane)
  docs/                      This file, contract-requests.md, lane notes
Native/                      Shared with iOS; engine lane adds macOS support only
```

Dependency direction: `App -> WalletUI + WalletEngine -> WalletCore`.
WalletUI never imports WalletEngine or Native; WalletEngine never imports
SwiftUI/AppKit UI code. Both talk only through `WalletCore.WalletServices`.

## Composition root (App target)

```swift
import SwiftUI
import WalletCore
import WalletEngine
import WalletUI

@main
struct FearlessMacApp: App {
    private let services = WalletEngineFactory.makeLiveServices()
    var body: some Scene {
        FearlessScenes(services: services)
    }
}
```

So the two public entry points are fixed:
- `WalletEngine`: `public enum WalletEngineFactory { public static func makeLiveServices(configuration: WalletEngineConfiguration = .default) -> WalletServices }`
  (must not throw or block; failures surface through the services).
- `WalletUI`: `public struct FearlessScenes: Scene { public init(services: WalletServices) }`
  (main window, Settings, menu bar extra, commands).

## Contract rules

- `WalletCore` is the only shared surface. Lanes never edit it; they write a
  request in `macOS/docs/contract-requests.md` (what, why, proposed Swift) and
  the coordinator applies it. Until then, work around it locally.
- Amounts cross the boundary as `TokenAmount` (exact digit strings). Never
  convert to `Double`; `Decimal` only for display and fiat.
- Errors cross as `WalletError` with user-facing messages.
- The UI treats `ChainID` / `AssetID.key` as opaque. Chain and asset icons are
  keyed by `iconName` = file stem in `remote-config/production/icons/chains/white/`.

## Security model

- App password (PasswordPolicy >= fair) protects every secret. The engine
  derives a key with scrypt and encrypts secrets with AES-GCM at rest in
  `~/Library/Application Support/Fearless/`. Secrets live in memory only while
  the vault is unlocked; locking drops them.
- Touch ID is offered only when the build can store the vault key in the
  data-protection keychain behind `SecAccessControl(.biometryCurrentSet)`;
  otherwise `biometricsAvailability()` reports `.unavailable`.
- Revealing a phrase, exporting, and every transfer re-verify the user
  (`UserApproval`). The UI auto-locks on sleep, screen lock and idle timeout.
- Copied secrets are marked concealed on the pasteboard and cleared after 60 s.
- No telemetry, no analytics, no closed-source libraries (owner rule:
  source-available licences count as closed). Every dependency must name its
  source and licence.

## Supported networks (first release)

Curated from `remote-config/production/chains/v13/chains.json`, keeping only
nodes that answer: Polkadot, Polkadot Asset Hub, Kusama, Kusama Asset Hub,
Westend (testnet), Ethereum, BNB Smart Chain, Polygon, Sepolia (testnet);
assets: native tokens plus USDT/USDC on Asset Hub and Ethereum.

## Build and test

- Each package: `swift build` / `swift test` in its folder. Use a private
  scratch path per lane when lanes build at the same time
  (`--scratch-path .build-<lane>`), because SwiftPM locks `.build`.
- App: `xcodegen` in `macOS/`, then
  `xcodebuild -project macOS/FearlessMac.xcodeproj -scheme FearlessMac -configuration Debug build`.
