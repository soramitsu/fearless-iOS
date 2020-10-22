import Foundation
import CommonWallet

final class WalletExtrinsicOpenCommand: WalletCommandProtocol {
    let extrinsicHash: String

    init(extrinsicHash: String) {
        self.extrinsicHash = extrinsicHash
    }

    func execute() throws {
        
    }
}
