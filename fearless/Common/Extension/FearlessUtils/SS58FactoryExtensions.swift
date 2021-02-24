import Foundation
import IrohaCrypto

enum SS58AddressFactoryError: Error {
    case unexpectedAddress
}

extension SS58AddressFactory {
    func extractAddressType(from address: String) throws -> SNAddressType {
        let addressTypeValue = try type(fromAddress: address)

        guard let addressType = SNAddressType(rawValue: addressTypeValue.uint8Value) else {
            throw SS58AddressFactoryError.unexpectedAddress
        }

        return addressType
    }

    func accountId(from address: String) throws -> Data {
        let addressType = try extractAddressType(from: address)
        return try accountId(fromAddress: address, type: addressType)
    }
}
