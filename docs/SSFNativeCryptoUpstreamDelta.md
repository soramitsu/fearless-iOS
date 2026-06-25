# SSF Native Crypto Upstream Delta

This document records the exact native crypto package-state contract that still has to be carried locally for the pinned `shared-features-spm` revision:

- Revision:
  - `3ad0fe928333c9ac28972e3669ca733c6972f060`

## Required upstream changes

### 1. `Sources/IrohaCrypto/include/module.modulemap`

Expected contents:

```modulemap
framework module IrohaCrypto {
    umbrella "."

    export *
    module * { export * }
}
```

Reason:
- avoids the umbrella-header path-resolution failure seen under the current Xcode/SwiftPM dependency scanner

### 2. `Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h`

Expected contents:

```objc
// Temporary umbrella header to satisfy IrohaCrypto module.modulemap
#import <Foundation/Foundation.h>
```

### 3. `Sources/IrohaCrypto/IrohaCrypto-umbrella.h`

Expected contents:

```objc
// Temporary umbrella header to satisfy IrohaCrypto module.modulemap
#import <Foundation/Foundation.h>
```

Reason:
- current toolchains may look for the umbrella header from either the include directory or the parent source directory

### 4. `Package.swift` `IrohaCrypto` target

Expected linker settings block:

```swift
            linkerSettings: [
                .linkedFramework("sorawallet")
            ]
```

Reason:
- the three crypto XCFrameworks are static archives wrapped as frameworks and should not be embedded into the app bundle
- only the dynamic `sorawallet` framework still needs an explicit link directive here

## Repo-owned contract sources

These repo files are the canonical local source of truth:

- `scripts/deps/templates/IrohaCrypto.module.modulemap`
- `scripts/deps/templates/IrohaCrypto-umbrella.h`
- `scripts/deps/templates/IrohaCrypto.linker-settings.swiftfrag`
- `scripts/deps/export-native-crypto-upstream-delta.sh`

## Exporting the delta

To produce a portable directory of the current upstream delta:

```bash
bash scripts/deps/export-native-crypto-upstream-delta.sh
```

This writes:

- `build/native-crypto-upstream-delta/Sources/IrohaCrypto/include/module.modulemap`
- `build/native-crypto-upstream-delta/Sources/IrohaCrypto/include/IrohaCrypto-umbrella.h`
- `build/native-crypto-upstream-delta/Sources/IrohaCrypto/IrohaCrypto-umbrella.h`
- `build/native-crypto-upstream-delta/IrohaCrypto.linker-settings.swiftfrag`

That output is intended to be the handoff artifact for upstreaming or vendoring the remaining `shared-features-spm` native crypto delta.

## Exit condition for Milestone 3

Milestone 3 is complete when the pinned `shared-features-spm` source already contains this delta and the repo no longer needs to mutate the resolved checkout after package resolution.
