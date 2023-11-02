import Foundation
import WalletConnectSign
import SSFModels
import SSFUtils
import Web3
import RobinHood

protocol WalletConnectPayloadFactory {
    func createTransactionPayload(
        request: Request,
        method: WalletConnectMethod,
        chain: ChainModel
    ) async throws -> WalletConnectPayload
}

final class WalletConnectPayloadFactoryImpl: WalletConnectPayloadFactory {
    private lazy var polkadotParser: WalletConnectPolkadotParser = {
        WalletConnectPolkadorParserImpl()
    }()

    func createTransactionPayload(
        request: Request,
        method: WalletConnectMethod,
        chain: ChainModel
    ) async throws -> WalletConnectPayload {
        switch method {
        case .polkadotSignTransaction:
            return try await createPolkadotTransactionPayload(params: request.params, chain: chain)
        case .polkadotSignMessage:
            return try createPolkadorSignMassagePayload(params: request.params)
        case .ethereumSignTransaction, .ethereumSendTransaction:
            return try createEthereumTransactionPayload(for: request.params)
        case .ethereumPersonalSign:
            return try createPersonalSignPayload(params: request.params)
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

    // MARK: Private methods

    private func createPolkadotTransactionPayload(
        params: AnyCodable,
        chain: ChainModel
    ) async throws -> WalletConnectPayload {
        let polkadotTransaction = try params.get(WalletConnectPolkadotTransaction.self)
        let parsedTransaction = try await polkadotParser.parse(
            transactionPayload: polkadotTransaction.transactionPayload,
            chain: chain
        )
        let txDetails = try parsedTransaction.toScaleCompatibleJSON()

        return WalletConnectPayload(
            address: polkadotTransaction.address,
            payload: AnyCodable(polkadotTransaction.transactionPayload),
            stringRepresentation: params.stringRepresentation,
            txDetails: txDetails
        )
    }

    private func createPolkadorSignMassagePayload(
        params: AnyCodable
    ) throws -> WalletConnectPayload {
        let json = try params.get(JSON.self)

        guard let address = json.address?.stringValue,
              let message = json.message?.stringValue
        else {
            throw JSONRPCError.invalidParams
        }

        let txDetails = try message.toScaleCompatibleJSON()
        return WalletConnectPayload(
            address: address,
            payload: AnyCodable(message),
            stringRepresentation: message,
            txDetails: txDetails
        )
    }

    private func createEthereumTransactionPayload(for params: AnyCodable) throws -> WalletConnectPayload {
        let transactions = try params.get([WalletConnectEthereumTransaction].self)
        guard let transaction = transactions.first else {
            throw JSONRPCError.invalidParams
        }

        let originalData = try JSONEncoder().encode(transaction)

        let txDetaild = try transaction.toScaleCompatibleJSON()
        return WalletConnectPayload(
            address: transaction.from,
            payload: AnyCodable(originalData),
            stringRepresentation: params.stringRepresentation,
            txDetails: txDetaild
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

        let txDetails = try stringRepresentation.or(params.stringRepresentation).toScaleCompatibleJSON()
        return WalletConnectPayload(
            address: address,
            payload: AnyCodable(persomalSignData),
            stringRepresentation: stringRepresentation ?? params.stringRepresentation,
            txDetails: txDetails
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

        let txDetails = try stringRepresentation.or("").toScaleCompatibleJSON()
        return WalletConnectPayload(
            address: address,
            payload: AnyCodable(hash),
            stringRepresentation: stringRepresentation ?? params.stringRepresentation,
            txDetails: txDetails
        )
    }
}
