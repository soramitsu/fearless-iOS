import Foundation

enum TonConnectDessision {
    case approve(
        manifest: TonConnectManifest,
        params: TonConnectParameters,
        invocationId: String
    )
    case reject(invocationId: String)
}
