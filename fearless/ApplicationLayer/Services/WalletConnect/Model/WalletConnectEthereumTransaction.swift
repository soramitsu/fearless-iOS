import Foundation
import BigInt
import Web3

struct WalletConnectEthereumTransaction: Codable {
    let from: String?
    let to: String?
    let data: String?

    let gasLimit: BigUInt?
    let gasPrice: BigUInt?
    let value: BigUInt?
    let nonce: BigUInt?

    enum CodingKeys: String, CodingKey {
        case from
        case to
        case data
        case gasLimit
        case gasPrice
        case value
        case nonce
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        from = try container.decode(String?.self, forKey: .from)
        to = try container.decode(String?.self, forKey: .to)
        data = try container.decode(String?.self, forKey: .data)

        let gasLimitString = try container.decodeIfPresent(String.self, forKey: .gasLimit)
        let gasPriceString = try container.decodeIfPresent(String.self, forKey: .gasPrice)
        let valueString = try container.decodeIfPresent(String.self, forKey: .value)
        let nonceString = try container.decodeIfPresent(String.self, forKey: .nonce)

        gasLimit = BigUInt.fromHexString(gasLimitString)
        gasPrice = BigUInt.fromHexString(gasPriceString)
        value = BigUInt.fromHexString(valueString)
        nonce = BigUInt.fromHexString(nonceString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(data, forKey: .data)

        try container.encode(gasLimit?.toHexString(), forKey: .gasLimit)
        try container.encode(gasPrice?.toHexString(), forKey: .gasPrice)
        try container.encode(value?.toHexString(), forKey: .value)
        try container.encode(nonce?.toHexString(), forKey: .nonce)
    }

    func mapToWeb3() throws -> EthereumTransaction {
        var transactionData = EthereumData([])
        if let data = data {
            transactionData = (try? EthereumData(ethereumValue: data)) ?? EthereumData([])
        }

        return EthereumTransaction(
            nonce: nonce?.toEthereumQuantity(),
            gasPrice: gasPrice?.toEthereumQuantity(),
            maxFeePerGas: gasPrice?.toEthereumQuantity(),
            maxPriorityFeePerGas: gasPrice?.toEthereumQuantity(),
            gasLimit: gasLimit?.toEthereumQuantity(),
            from: try EthereumAddress(rawAddress: from?.hexToBytes()),
            to: try EthereumAddress(rawAddress: to?.hexToBytes()),
            value: EthereumQuantity(quantity: value),
            data: transactionData,
            accessList: [:],
            transactionType: .legacy
        )
    }
}

extension EthereumAddress {
    init?(rawAddress: Bytes?) throws {
        guard let rawAddress = rawAddress else {
            return nil
        }
        try self.init(rawAddress: rawAddress)
    }
}

extension EthereumQuantity {
    init?(quantity: BigUInt?) {
        guard let quantity = quantity else {
            return nil
        }
        self.init(quantity: quantity)
    }
}
