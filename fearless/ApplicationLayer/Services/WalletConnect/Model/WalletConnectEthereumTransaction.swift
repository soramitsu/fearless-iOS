import Foundation
import BigInt
import Web3

struct WalletConnectEthereumTransaction: Codable {
    let from: String
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

        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String?.self, forKey: .to)
        data = try container.decode(String?.self, forKey: .data)

        let gasLimitString = try? container.decode(String?.self, forKey: .gasLimit)
        let gasPriceString = try? container.decode(String?.self, forKey: .gasPrice)
        let valueString = try? container.decode(String?.self, forKey: .value)
        let nonceString = try? container.decode(String?.self, forKey: .nonce)

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
        guard
            let toAddress = to,
            let value = value
        else {
            throw ConvenienceError(error: "Missing requared params WCEthereumTransaction")
        }

        let from = try EthereumAddress(rawAddress: from.hexToBytes())
        let to = try EthereumAddress(rawAddress: toAddress.hexToBytes())
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
            from: from,
            to: to,
            value: EthereumQuantity(quantity: value),
            data: transactionData,
            accessList: [:],
            transactionType: .legacy
        )
    }
}
