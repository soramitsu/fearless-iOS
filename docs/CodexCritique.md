# Fearless iOS Codebase Critique

## Scene and window management relies on deprecated APIs
- `FearlessApplication.dropSession()` pulls the first entry from `UIApplication.shared.windows`. This API has been deprecated since iOS 15 and fails in multi-scene environments (for example on iPad multi-window or Mac Catalyst), which means the PIN screen may never be presented when the app runs outside the legacy single-window scene. Prefer iterating over `UIApplication.shared.connectedScenes` and their `UIWindowScene` instances to obtain the active foreground window instead of assuming `.windows.first`.
- `MainTabBarViewFactory.createView()` still relies on `UIApplication.shared.keyWindow` to obtain the status-presenting window. `keyWindow` has been removed in scene-based apps and returns `nil` when multiple scenes are active, so the entire tab bar assembly fails. Refactor the factory to accept a `UIWindowScene` (or the hosting `UIWindow`) from the caller and remove the implicit singleton lookup.

## Global singletons make composition and testing brittle
The composition roots instantiate collaborators by touching singletons (`KeychainManager.shared`, `LocalizationManager.shared`, `WalletConnectServiceImpl.shared`, `EventCenter.shared`, `ReachabilityManager.shared`, etc.). This tight coupling makes it difficult to inject fakes in unit tests and complicates modularisation. Extract explicit dependency containers or pass protocol-based collaborators into factories instead of resolving them statically.

## Cancellation does not silence transaction-history callbacks
`HistoryService.fetchTransactionHistory` always dispatches the completion block once the underlying operation finishes, even when the returned `CancellableCall` is cancelled. Consumers that cancel during teardown still receive callbacks on the provided queue, which can crash if the callee has been deallocated. The completion block should guard `targetOperation.isCancelled` (or expose a cancellation flag) before emitting a result.

