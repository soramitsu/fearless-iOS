import Foundation
import IrohaCrypto
import SSFModels
import SSFUtils

public enum AddressFactory {
    private static let substrateFactory = SS58AddressFactory()

    private static func chainFormat(of chain: ChainModel) -> SFChainFormat {
        chain.isEthereumBased ? .sfEthereum : .sfSubstrate(chain.addressPrefix)
    }

    public static func address(
        for accountId: AccountId,
        chainFormat: SFChainFormat
    ) throws -> AccountAddress {
        try accountId.toAddress(using: chainFormat)
    }

    public static func accountId(
        from address: AccountAddress,
        chainFormat: SFChainFormat
    ) throws -> AccountId {
        try address.toAccountId(using: chainFormat)
    }

    public static func accountId(
        from address: AccountAddress,
        chain: ChainModel
    ) throws -> AccountId {
        try address.toAccountId(using: chainFormat(of: chain))
    }

    public static func randomAccountId(for chainFormat: SFChainFormat) -> AccountId {
        switch chainFormat {
        case .sfEthereum:
            return Data(count: EthereumConstants.accountIdLength)
        case .sfSubstrate:
            return Data(count: SubstrateConstants.accountIdLength)
        }
    }
}

public extension AccountAddress {
    func toAccountId(using conversion: SFChainFormat) throws -> AccountId {
        switch conversion {
        case .sfEthereum:
            return try AccountId(hexStringSSF: self)
        case let .sfSubstrate(prefix):
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix)
        }
    }

    func toAccountIdWithTryExtractPrefix() throws -> AccountId {
        if hasPrefix("0x") {
            return try AccountId(hexStringSSF: self)
        } else {
            let prefix = try SS58AddressFactory().type(fromAddress: self)
            return try SS58AddressFactory().accountId(fromAddress: self, type: prefix.uint16Value)
        }
    }
}

public extension AccountId {
    func toAddress(using conversion: SFChainFormat) throws -> AccountAddress {
        switch conversion {
        case .sfEthereum:
            return toHex(includePrefix: true)
        case let .sfSubstrate(prefix):
            return try SS58AddressFactory().address(fromAccountId: self, type: prefix)
        }
    }
}

extension ChainAccountModel {
    func toAddress(addressPrefix: UInt16) -> AccountAddress? {
        try? accountId.toAddress(using: .sfSubstrate(addressPrefix))
    }
}
