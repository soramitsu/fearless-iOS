import Foundation
import BigInt
import FearlessWalletConnect
import SSFModels
import SSFUtils
import Web3

protocol WalletConnectEthereumQuoting {
    func pendingNonce(of address: Data) async throws -> BigUInt
    func gasPrice() async throws -> BigUInt
    func supportsEip1559() async -> Bool
    func estimateGas(from: Data, to: Data, value: BigUInt, data: Data) async throws -> BigUInt
}

final class WalletConnectEthereumQuoteService: BaseEthereumService, WalletConnectEthereumQuoting {
    func pendingNonce(of address: Data) async throws -> BigUInt {
        let address = try EthereumAddress(rawAddress: Array(address))
        return try await queryNonce(ethereumAddress: address).quantity
    }

    func gasPrice() async throws -> BigUInt {
        try await queryGasPrice().quantity
    }

    func supportsEip1559() async -> Bool {
        await checkChainSupportEip1559()
    }

    func estimateGas(from: Data, to: Data, value: BigUInt, data: Data) async throws -> BigUInt {
        let sender = try EthereumAddress(rawAddress: Array(from))
        let recipient = try EthereumAddress(rawAddress: Array(to))
        let call = EthereumCall(
            from: sender,
            to: recipient,
            value: EthereumQuantity(quantity: value),
            data: EthereumData(Array(data))
        )
        return try await queryGasLimit(call: call).quantity
    }
}

protocol WalletConnectEthereumRequestPreparing {
    func prepareTransaction(
        params: AnyCodable,
        chain: ChainModel,
        account: ChainAccountResponse
    ) async throws -> WalletConnectEthereumTransactionQuote

    func prepareTypedData(
        params: AnyCodable,
        chain: ChainModel
    ) throws -> WalletConnectTypedData
}

/// Fixes every field of an EVM transaction, the gas values included, before the
/// confirmation opens, and checks typed data against the request's network.
final class WalletConnectEthereumRequestPreparer: WalletConnectEthereumRequestPreparing {
    private let quotingFactory: (ChainModel) throws -> WalletConnectEthereumQuoting

    init(
        quotingFactory: @escaping (ChainModel) throws -> WalletConnectEthereumQuoting = { chain in
            guard let connection = ChainRegistryFacade.sharedRegistry.getEthereumConnection(for: chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }
            return WalletConnectEthereumQuoteService(ws: connection)
        }
    ) {
        self.quotingFactory = quotingFactory
    }

    func prepareTransaction(
        params: AnyCodable,
        chain: ChainModel,
        account: ChainAccountResponse
    ) async throws -> WalletConnectEthereumTransactionQuote {
        let transaction = try WalletConnectEthereumTransactionParams(params: params)
        let chainId = try WalletConnectEthereumChainId.value(of: chain)

        guard transaction.from == account.accountId else {
            throw WalletConnectRequestError.accountNotApproved
        }

        if let requestedChainId = transaction.chainId, requestedChainId != chainId {
            throw WalletConnectRequestError.networkMismatch
        }

        // A contract deployment has no recipient to show.
        guard let recipient = transaction.to else {
            throw WalletConnectRequestError.unsupported
        }

        do {
            let quoting = try quotingFactory(chain)

            let nonce: BigUInt
            if let requestedNonce = transaction.nonce {
                nonce = requestedNonce
            } else {
                nonce = try await quoting.pendingNonce(of: transaction.from)
            }

            let gasLimit: BigUInt
            if let requestedGasLimit = transaction.gasLimit {
                gasLimit = requestedGasLimit
            } else {
                gasLimit = try await quoting.estimateGas(
                    from: transaction.from,
                    to: recipient,
                    value: transaction.value,
                    data: transaction.data
                )
            }

            // The wallet quotes the gas price itself, as for its own transfers; a price the
            // dApp suggests is not used.
            let gasPrice = try await quoting.gasPrice()
            let fee: WalletConnectEthereumTransactionQuote.Fee = await quoting.supportsEip1559()
                ? .eip1559(maxFeePerGas: gasPrice, maxPriorityFeePerGas: gasPrice)
                : .legacy(gasPrice: gasPrice)

            return WalletConnectEthereumTransactionQuote(
                chainId: chainId,
                from: transaction.from,
                to: recipient,
                value: transaction.value,
                data: transaction.data,
                nonce: nonce,
                gasLimit: gasLimit,
                fee: fee,
                tokenCall: WalletConnectTokenCall(data: transaction.data)
            )
        } catch {
            throw WalletConnectRequestError.feeUnavailable
        }
    }

    func prepareTypedData(
        params: AnyCodable,
        chain: ChainModel
    ) throws -> WalletConnectTypedData {
        let chainId = try WalletConnectEthereumChainId.value(of: chain)

        guard
            let parameters = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(params)) as? [Any],
            parameters.count >= 2
        else {
            throw WalletConnectRequestError.unsupported
        }

        let typedDataObject: Any?
        if let typedDataString = parameters[1] as? String, let typedData = typedDataString.data(using: .utf8) {
            typedDataObject = try? JSONSerialization.jsonObject(with: typedData)
        } else {
            typedDataObject = parameters[1]
        }

        // The legacy array format (v1) has no domain, so nothing binds it to a network.
        guard let typedData = typedDataObject as? [String: Any] else {
            throw WalletConnectRequestError.unsupported
        }

        let message: TypedMessage
        do {
            message = try TypedMessage(json: typedData, version: .v4)
        } catch {
            throw WalletConnectRequestError.unsupported
        }

        guard message.types["EIP712Domain"] != nil, message.types[message.primaryType] != nil else {
            throw WalletConnectRequestError.unsupported
        }

        let domain = typedData["domain"] as? [String: Any] ?? [:]
        if let requestedChainIdValue = domain["chainId"] {
            guard let requestedChainId = WalletConnectEthereumChainId.parse(typedValue: requestedChainIdValue) else {
                throw WalletConnectRequestError.unsupported
            }

            guard requestedChainId == chainId else {
                throw WalletConnectRequestError.networkMismatch
            }

            // The hash encodes the parsed domain; it must carry the chain id checked here.
            guard let hashedChainId = message.domain.chainId, BigUInt(hashedChainId) == requestedChainId else {
                throw WalletConnectRequestError.unsupported
            }
        }

        let signingInput: Data
        do {
            signingInput = try hash(message: message, version: .v4)
        } catch {
            throw WalletConnectRequestError.unsupported
        }

        let verifyingContract = message.domain.verifyingContract.flatMap { try? Data(hexStringSSF: $0) }

        return WalletConnectTypedData(
            signingInput: signingInput,
            primaryType: message.primaryType,
            domainName: message.domain.name,
            verifyingContract: verifyingContract,
            allowance: WalletConnectTokenAllowance(
                primaryType: message.primaryType,
                message: message.message.first ?? [:],
                verifyingContract: verifyingContract
            )
        )
    }
}

/// EVM chain ids are stored as decimal strings ("1", "56"); dApps also send `0x` hex.
enum WalletConnectEthereumChainId {
    static func value(of chain: ChainModel) throws -> BigUInt {
        guard chain.isEthereumBased, let chainId = parse(chain.chainId) else {
            throw WalletConnectRequestError.networkMismatch
        }
        return chainId
    }

    static func parse(_ value: String) -> BigUInt? {
        if value.hasPrefix("0x") {
            return BigUInt(value.dropFirst(2), radix: 16)
        }
        guard !value.isEmpty, value.allSatisfy({ ("0" ... "9").contains($0) }) else {
            return nil
        }
        return BigUInt(value, radix: 10)
    }

    static func parse(typedValue: Any) -> BigUInt? {
        switch typedValue {
        case let string as String:
            return parse(string)
        case let number as NSNumber where !CFNumberIsFloatType(number as CFNumber) && number.int64Value >= 0:
            return BigUInt(number.uint64Value)
        default:
            return nil
        }
    }
}

/// The fields of an `eth_sendTransaction` or `eth_signTransaction` request.
struct WalletConnectEthereumTransactionParams {
    let from: Data
    let to: Data?
    let value: BigUInt
    let data: Data
    let gasLimit: BigUInt?
    let nonce: BigUInt?
    let chainId: BigUInt?

    init(params: AnyCodable) throws {
        guard let fields = (try? params.get(JSON.self))?.arrayValue?.first?.dictValue else {
            throw WalletConnectRequestError.unsupported
        }

        guard let from = try Self.address(fields["from"]) else {
            throw WalletConnectRequestError.unsupported
        }

        self.from = from
        to = try Self.address(fields["to"])
        value = try Self.quantity(fields["value"]) ?? .zero
        data = try Self.bytes(fields["data"] ?? fields["input"]) ?? Data()
        gasLimit = try Self.quantity(fields["gas"] ?? fields["gasLimit"])
        nonce = try Self.quantity(fields["nonce"])
        chainId = try Self.chainId(fields["chainId"])
    }

    private static func address(_ json: JSON?) throws -> Data? {
        guard let json = json, !json.isNull else {
            return nil
        }
        guard
            let string = json.stringValue,
            let address = try? Data(hexStringSSF: string),
            address.count == EthereumConstants.accountIdLength
        else {
            throw WalletConnectRequestError.unsupported
        }
        return address
    }

    /// JSON-RPC quantities are `0x` hex; a decimal string would be ambiguous.
    private static func quantity(_ json: JSON?) throws -> BigUInt? {
        guard let json = json, !json.isNull else {
            return nil
        }
        if let number = json.unsignedIntValue {
            return BigUInt(number)
        }
        guard let string = json.stringValue, string.hasPrefix("0x") else {
            throw WalletConnectRequestError.unsupported
        }
        let digits = string.dropFirst(2)
        if digits.isEmpty {
            return .zero
        }
        guard let value = BigUInt(digits, radix: 16) else {
            throw WalletConnectRequestError.unsupported
        }
        return value
    }

    private static func chainId(_ json: JSON?) throws -> BigUInt? {
        guard let json = json, !json.isNull else {
            return nil
        }
        if let number = json.unsignedIntValue {
            return BigUInt(number)
        }
        guard let string = json.stringValue, let chainId = WalletConnectEthereumChainId.parse(string) else {
            throw WalletConnectRequestError.unsupported
        }
        return chainId
    }

    private static func bytes(_ json: JSON?) throws -> Data? {
        guard let json = json, !json.isNull else {
            return nil
        }
        guard let string = json.stringValue, string.hasPrefix("0x") else {
            throw WalletConnectRequestError.unsupported
        }
        if string == "0x" {
            return Data()
        }
        guard let data = try? Data(hexStringSSF: string) else {
            throw WalletConnectRequestError.unsupported
        }
        return data
    }
}

extension WalletConnectTokenCall {
    private static let transferSelector = Data([0xA9, 0x05, 0x9C, 0xBB])
    private static let approveSelector = Data([0x09, 0x5E, 0xA7, 0xB3])

    /// Decodes ERC-20 `transfer(address,uint256)` and `approve(address,uint256)`.
    init?(data: Data) {
        guard data.count == 68 else {
            return nil
        }

        let selector = data.prefix(4)
        let addressWord = data.subdata(in: 4 ..< 36)
        let amount = BigUInt(data.subdata(in: 36 ..< 68))

        guard addressWord.prefix(12).allSatisfy({ $0 == 0 }) else {
            return nil
        }

        let address = Data(addressWord.suffix(20))

        switch selector {
        case Self.transferSelector:
            self = .transfer(recipient: address, amount: amount)
        case Self.approveSelector:
            self = .approve(spender: address, amount: amount)
        default:
            return nil
        }
    }
}

extension WalletConnectTokenAllowance {
    /// Reads the spender and amount of an EIP-2612 `Permit` and of Permit2 `PermitSingle`
    /// and `PermitTransferFrom`.
    init?(primaryType: String, message: [String: AnyObject], verifyingContract: Data?) {
        let token: Data?
        let amount: BigUInt?

        switch primaryType {
        case "Permit":
            token = verifyingContract
            amount = message["value"].flatMap { Self.amount(from: $0) }
        case "PermitSingle":
            let details = message["details"] as? [String: AnyObject]
            token = (details?["token"] as? String).flatMap { try? Data(hexStringSSF: $0) }
            amount = details?["amount"].flatMap { Self.amount(from: $0) }
        case "PermitTransferFrom":
            let permitted = message["permitted"] as? [String: AnyObject]
            token = (permitted?["token"] as? String).flatMap { try? Data(hexStringSSF: $0) }
            amount = permitted?["amount"].flatMap { Self.amount(from: $0) }
        default:
            return nil
        }

        guard
            let token = token,
            let amount = amount,
            let spender = (message["spender"] as? String).flatMap({ try? Data(hexStringSSF: $0) }),
            spender.count == EthereumConstants.accountIdLength
        else {
            return nil
        }

        self.init(token: token, spender: spender, amount: amount)
    }

    private static func amount(from value: AnyObject) -> BigUInt? {
        if let string = value as? String {
            return WalletConnectEthereumChainId.parse(string)
        }
        if let number = value as? NSNumber, !CFNumberIsFloatType(number as CFNumber), number.int64Value >= 0 {
            return BigUInt(number.uint64Value)
        }
        return nil
    }
}
