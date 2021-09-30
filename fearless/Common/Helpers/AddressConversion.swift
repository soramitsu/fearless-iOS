import Foundation
import IrohaCrypto

enum ChainFormat {
    case ethereum
    case substrate(_ prefix: UInt16)
}

extension AccountId {
    func toAddress(using conversion: ChainFormat) throws -> AccountAddress {
        switch conversion {
        case .ethereum:
            return toHex(includePrefix: true)
        case let .substrate(prefix):
            return try SS58AddressFactory().address(fromAccountId: self, type: prefix)
        }
    }
}

extension AccountAddress {
    func toAccountId(using conversion: ChainFormat) throws -> AccountId {
        switch conversion {
        case .ethereum:
            return try AccountId(hexString: self)
        case let .substrate(prefix):
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix)
        }
    }

    func toAccountId() throws -> AccountId {
        if hasPrefix("0x") {
            return try AccountId(hexString: self)
        } else {
            return try SS58AddressFactory().accountId(from: self)
        }
    }
}

extension ChainModel {
    var chainFormat: ChainFormat {
        if isEthereumBased {
            return .ethereum
        } else {
            return .substrate(addressPrefix)
        }
    }
}
