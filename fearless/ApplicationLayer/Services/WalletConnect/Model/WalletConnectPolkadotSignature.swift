import Foundation

struct WalletConnectPolkadotSignature: Codable {
    let id: UInt
    let signature: String

    /// The largest integer JavaScript reads exactly (2^53 - 1). dApps parse the answer in JavaScript, where a larger
    /// id turns into a BigInt that plain `JSON.stringify` cannot write.
    static let maximumId: UInt = 9_007_199_254_740_991

    static func makeId() -> UInt {
        UInt.random(in: 1 ... maximumId)
    }
}
