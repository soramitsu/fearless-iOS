# Read-only XCM services

`XcmAssembly.createReadOnlyServices` is the only way to get the XCM services. It accepts public
chain/account context only and never touches secret material. There is no construction entry point
that takes a key: the former `createExtrincisServices(fromChainData:...)` (raw `secretKeyData`,
signing and broadcasting with no authorization) and the `SigningWrapperData` type that carried the
key are gone, and `FromChainData` holds public identity only.

The returned `XcmReadOnlyServices` exposes discovery, destination fees and an
`XcmFeeEstimating` interface. A separate wrapper prevents downcasting that fee
interface into `XcmExtrinsicServiceProtocol`; the underlying service is built with a
signer that always rejects (`XcmReadOnlySigner`, hard-wired in `XcmAssembly`). Existing quotation
operations use their dummy signature path. No real wallet key is needed to browse or quote a route.

This API does not approve a transfer or qualify symbol-based route/fee matching.
The wallet's exact asset/route, freshness, signer and physical-send checks remain
mandatory. The wallet must instantiate its approved submission path separately
after confirming the intent and obtaining current signed authorization.

## Keeping it read-only

Run `python3 Native/scripts/test-xcm-read-only-boundary.py --root Native` from the app root before a release; this
project does not depend on hosted CI, although `.github/workflows/codecov.yml` runs the same script. On the code of
`Sources/SSFXCM`, with comments removed, it fails when:

- a name that carries or creates signing material shows up (`secretKeyData`,
  `TransactionSignerAssembly`, `SigningWrapperData`, `createExtrincisServices`);
- `XcmAssembly` exposes anything public besides `createReadOnlyServices`, or anything public takes a
  `TransactionSigner*`;
- an `XcmExtrinsicService` is built with anything but `XcmReadOnlySigner()`, or `XcmReadOnlySigner`
  stops throwing, or `XcmExtrinsicServices` (the bundle that holds the send-capable service) is public.

The script checks its own rules on synthetic sources first, so a rule that stops firing fails the
run.

## Tests

`Tests/ReadOnlyXCM/XcmReadOnlyServicesTests.swift` is the `ReadOnlyXCMTests` target of this package
and a byte-identical copy is compiled by the wallet test target. It checks exact fee inputs/results,
error propagation, failed mutation-interface casts and unconditional signing refusal.
`XcmAssemblyTests` (in `SSFXCMTests`) covers the assembled object.

Like every test target of the package, these need the iOS SDK (the native libraries are iOS-only
xcframeworks), so `swift test` does not build on macOS. The `Modules-XCM` scheme runs the XCM, SCALE
and call encoding tests on a simulator (`SSFUtilsTests`, `SSFXCMTests`, `ReadOnlyXCMTests`, and
`SSFTransferServiceTests`, which encodes calls against real Polkadot metadata):

```sh
xcodebuild test -scheme Modules-XCM -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0'
```

The scheme also builds `SSFPolkaswap`: `IrohaCrypto` links `sorawallet.framework` without declaring a
dependency, and building `SSFPolkaswap` is what puts the framework in place.

The `Modules-Package` scheme builds every test target of the package, and several of the others
(`SSFAccountManagmentTests`, `SSFAssetManagmentTests`, `SSFKeyPairTests`, `SSFStorageQueryKitTest`) do
not compile against the current sources, so use `Modules-XCM` until they are repaired.
