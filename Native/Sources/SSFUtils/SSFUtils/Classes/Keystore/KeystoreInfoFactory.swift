import Foundation
import IrohaCrypto
import SSFModels

public protocol KeystoreInfoFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> KeystoreInfo
}

public enum KeystoreInfoFactoryError: Error {
    case unsupportedCryptoType
    case unsupportedAddressType
}

public final class KeystoreInfoFactory: KeystoreInfoFactoryProtocol {
    public init() {}

    public func createInfo(from definition: KeystoreDefinition) throws -> KeystoreInfo {
        let cryptoTypeValue = definition.encoding.content.count > 1 ? definition.encoding
            .content[1] : nil

        guard let value = cryptoTypeValue, let cryptoType = CryptoType(rawValue: value) else {
            throw KeystoreInfoFactoryError.unsupportedCryptoType
        }

        let isEthereum = value == "ethereum"

        let chainType: ChainType?

        if let address = definition.address,
           let chainTypeValue = try? SS58AddressFactory().type(fromAddress: address)
        {
            chainType = chainTypeValue.uint16Value
        } else {
            chainType = nil
        }

        return KeystoreInfo(
            address: definition.address,
            chainType: chainType,
            cryptoType: cryptoType,
            meta: definition.meta,
            isEthereum: isEthereum
        )
    }
}
