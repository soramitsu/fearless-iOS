import Foundation
import TonSwift

enum TonAddressFactory {
    static func accountId(from address: AccountAddress) throws -> AccountId {
        let tonAddress = try TonSwift.Address.parse(address)
        return tonAddress.hash
    }
}

extension Data {
    func asTonAddress() throws -> TonSwift.Address {
        try TonSwift.Address.parse(accountId: self, workchainId: 0)
    }
}
