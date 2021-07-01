import Foundation
import IrohaCrypto

enum SS58AddressFactoryError: Error {
    case unexpectedAddress
}

// Deprecated: better not to use this methods anymore, will be removed when we get rid of SNAddressType
extension SS58AddressFactoryProtocol {
    func extractAddressType(from address: String) throws -> SNAddressType {
        let addressTypeValue = try type(fromAddress: address)

        guard let addressType = SNAddressType(rawValue: addressTypeValue.uint8Value) else {
            throw SS58AddressFactoryError.unexpectedAddress
        }

        return addressType
    }

    func accountId(from address: String) throws -> AccountId {
        let addressType = try extractAddressType(from: address)
        return try accountId(fromAddress: address, type: addressType)
    }

    func accountId(fromAddress: AccountAddress, type: SNAddressType) throws -> AccountId {
        try accountId(fromAddress: fromAddress, type: UInt16(type.rawValue))
    }

    func addressFromAccountId(data: AccountId, type: SNAddressType) throws -> AccountAddress {
        try address(fromAccountId: data, type: UInt16(type.rawValue))
    }

    func address(fromPublicKey: IRPublicKeyProtocol, type: SNAddressType) throws -> AccountAddress {
        try address(fromAccountId: fromPublicKey.rawData(), type: UInt16(type.rawValue))
    }
}
