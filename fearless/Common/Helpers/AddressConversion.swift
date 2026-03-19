import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels

enum ChainFormat {
    case ethereum
    case substrate(_ prefix: UInt16)

    func asSfCrypto() -> SFChainFormat {
        switch self {
        case .ethereum:
            return .ethereum
        case let .substrate(prefix):
            return .substrate(prefix)
        }
    }
}

struct AddressFactory {
    private static func chainFormat(of chain: ChainModel) -> ChainFormat {
        chain.isEthereumBased ? .ethereum : .substrate(chain.addressPrefix)
    }

    static func address(for accountId: AccountId, chain: ChainModel) throws -> AccountAddress {
        try accountId.toAddress(using: chainFormat(of: chain))
    }

    static func address(for accountId: AccountId, chainFormat: ChainFormat) throws -> AccountAddress {
        try accountId.toAddress(using: chainFormat)
    }

    static func accountId(from address: AccountAddress, chain: ChainModel) throws -> AccountId {
        try address.toAccountId(using: chainFormat(of: chain))
    }

    static func randomAccountId(for chain: ChainModel) -> AccountId {
        switch chainFormat(of: chain) {
        case .ethereum:
            return Data(count: EthereumConstants.accountIdLength)
        case .substrate:
            return Data(count: SubstrateConstants.accountIdLength)
        }
    }

    // Instance wrappers for compatibility where an AddressFactory instance is injected
    func address(for accountId: AccountId, chain: ChainModel) throws -> AccountAddress {
        try AddressFactory.address(for: accountId, chain: chain)
    }

    func address(for accountId: AccountId, chainFormat: ChainFormat) throws -> AccountAddress {
        try AddressFactory.address(for: accountId, chainFormat: chainFormat)
    }

    func accountId(from address: AccountAddress, chain: ChainModel) throws -> AccountId {
        try AddressFactory.accountId(from: address, chain: chain)
    }

    func randomAccountId(for chain: ChainModel) -> AccountId {
        AddressFactory.randomAccountId(for: chain)
    }
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
            return try AccountId(hexStringSSF: self)
        case let .substrate(prefix):
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix)
        }
    }

    func toAccountId() throws -> AccountId {
        if hasPrefix("0x") {
            return try AccountId(hexStringSSF: self)
        } else {
            return try SS58AddressFactory().accountId(from: self)
        }
    }

    func toAccountIdWithTryExtractPrefix() throws -> AccountId {
        if hasPrefix("0x") {
            return try AccountId(hexStringSSF: self)
        } else {
            let prefix = try SS58AddressFactory().type(fromAddress: self)
            return try SS58AddressFactory().accountId(fromAddress: self, addressPrefix: prefix.uint16Value)
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
