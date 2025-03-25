import Foundation
import TonSwift

extension TonSwift.Address {
    static func random() -> TonSwift.Address {
        TonSwift.Address.mock(workchain: 0, seed: "testResolvableAddressResolvedCoding")
    }

    func asAccountId() throws -> AccountId {
        try JSONEncoder().encode(self)
    }
}

extension AccountId {
    func asTonAddress() throws -> TonSwift.Address {
        try JSONDecoder().decode(TonSwift.Address.self, from: self)
    }
}
