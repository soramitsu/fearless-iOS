import Foundation
import WalletConnectSign
import SSFModels
// import WalletConnectSwiftV2
import SSFUtils
import Web3

protocol WalletConnectPayloadFactory {
    func createTransactionPayload(
        request: Request,
        method: WalletConnectMethod
    ) throws -> WalletConnectPayload
}

final class WalletConnectPayloadFactoryImpl: WalletConnectPayloadFactory {
    func createTransactionPayload(
        request: Request,
        method: WalletConnectMethod
    ) throws -> WalletConnectPayload {
        switch method {
        case .polkadotSignTransaction:
            return try createPolkadotTransactionPayload(
                params: request.params
            )
//        case .polkadotSignMessage:
        ////            return try createPolkadotSignMessage(
        ////                for: wallet,
        ////                chain: chain,
        ////                params: params,
        ////                method: method
        ////            )
//            return JSON.null
        case .ethereumSignTransaction, .ethereumSendTransaction:
            return try createEthereumTransactionPayload(for: request.params)
        case .ethereumPersonalSign:
            return try createPersonalSignPayload(
                params: request.params
            )
        case .ethereumSignTypeData:
            return try createSignTypesDataPayload(
                params: request.params,
                version: .v1
            )
        case .ethereumSignTypeDataV4:
            return try createSignTypesDataPayload(
                params: request.params,
                version: .v4
            )
        }
    }

//    func createSigningType(
//        chain: ChainModel,
//        method: WalletConnectMethod
//    ) throws -> DAppSigningType {
//        switch method {
//        case .polkadotSignTransaction:
//            return .extrinsic(chain: chain)
    ////        case .polkadotSignMessage:
    ////            return .bytes(chain: chain)
//        case .ethereumSendTransaction:
//            return .ethereumSendTransaction(chain: chain)
//        case .ethereumSignTransaction:
//            return .ethereumSignTransaction(chain: chain)
//        case .ethereumPersonalSign, .ethereumSignTypeData, .ethereumSignTypeDataV4:
//            return .ethereumBytes(chain: chain)
//        }
//    }

    // MARK: Private methods

    private func createPolkadotTransactionPayload(
        params: AnyCodable
    ) throws -> WalletConnectPayload {
        let polkadotTransaction = try params.get(WalletConnectPolkadotTransaction.self)

        return WalletConnectPayload(
            address: polkadotTransaction.address,
            payload: AnyCodable(polkadotTransaction.transactionPayload),
            stringRepresentation: params.stringRepresentation
        )
    }

    private func createEthereumTransactionPayload(for params: AnyCodable) throws -> WalletConnectPayload {
        let transactions = try params.get([WalletConnectEthereumTransaction].self)
        guard let transaction = transactions.first else {
            throw JSONRPCError.invalidParams
        }

        let originalData = try JSONEncoder().encode(transaction)

        return WalletConnectPayload(
            address: transaction.from,
            payload: AnyCodable(originalData),
            stringRepresentation: params.stringRepresentation
        )
    }

    private func createPersonalSignPayload(
        params: AnyCodable
    ) throws -> WalletConnectPayload {
        let json = try params.get([String].self)

        guard let address = json[safe: 1], let message = json[safe: 0] else {
            throw JSONRPCError.invalidParams
        }

        let messageData = try Data(hexStringSSF: message)
        let stringRepresentation = String(data: messageData, encoding: .utf8)

        let persomalSignData = messageData.ethereumPersonalSignMessage()

        return WalletConnectPayload(
            address: address,
            payload: AnyCodable(persomalSignData),
            stringRepresentation: stringRepresentation ?? params.stringRepresentation
        )
    }

    private func createSignTypesDataPayload(
        params: AnyCodable,
        version: SignTypedDataVersion
    ) throws -> WalletConnectPayload {
        let json = try params.get([String].self)

        guard
            let address = json[safe: 0],
            let typeString = json[safe: 1],
            let typeData = typeString.data(using: .utf8),
            let json = try JSONSerialization.jsonObject(with: typeData) as? [String: Any]
        else {
            throw JSONRPCError.invalidParams
        }

        let eip712TypeData = try TypedMessage(json: json, version: version)
        let hash = try hash(message: eip712TypeData, version: version)

        let jsonData = try JSONSerialization.data(withJSONObject: json)
        let stringRepresentation = String(data: jsonData, encoding: .utf8)

        return WalletConnectPayload(
            address: address,
            payload: AnyCodable(hash),
            stringRepresentation: stringRepresentation ?? params.stringRepresentation
        )
    }
}
