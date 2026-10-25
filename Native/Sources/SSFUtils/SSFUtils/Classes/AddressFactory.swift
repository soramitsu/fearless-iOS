import Foundation
import IrohaCrypto
import SSFModels

enum AddressFactory {
    static func accountId(
        from address: AccountAddress,
        chainFormat: SFChainFormat
    ) throws -> AccountId {
        try address.toAccountId(using: chainFormat)
    }
}

extension AccountAddress {
    func toAccountId(using conversion: SFChainFormat) throws -> AccountId {
        switch conversion {
        case .sfEthereum:
            return try AccountId(hexStringSSF: self)
        case let .sfSubstrate(prefix):
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix)
        }
    }
}
