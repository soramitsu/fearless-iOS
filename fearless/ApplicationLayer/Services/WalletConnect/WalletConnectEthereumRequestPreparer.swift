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

            let decoded = WalletConnectTokenCall.decode(transaction.data)
            return WalletConnectEthereumTransactionQuote(
                chainId: chainId,
                from: transaction.from,
                to: recipient,
                value: transaction.value,
                data: transaction.data,
                nonce: nonce,
                gasLimit: gasLimit,
                fee: fee,
                tokenCall: decoded?.call,
                trailingDataLength: decoded?.trailingBytes ?? 0
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
        let declaredDomainFields = Set((message.types["EIP712Domain"] ?? []).map(\.name))
        if let requestedChainIdValue = domain["chainId"] {
            // Only the domain fields `EIP712Domain` declares are hashed. A chain id the domain carries without
            // declaring it would be shown and checked here yet left out of the signature, which would then be valid
            // on every network.
            guard
                declaredDomainFields.contains("chainId"),
                let requestedChainId = WalletConnectEthereumChainId.parse(typedValue: requestedChainIdValue)
            else {
                throw WalletConnectRequestError.unsupported
            }

            guard requestedChainId == chainId else {
                throw WalletConnectRequestError.networkMismatch
            }

            // The hash is computed from the domain as `TypedMessage` parsed it: that chain id must be the one
            // checked here.
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

        // Everything shown is read the way the hash reads it: the domain as `TypedMessage` parsed it and the message
        // object it hashes, and of both only what the types declare.
        let hashedDomain = message.domain.encoded()
        let hashedMessage = message.message.first ?? [:]
        let declaredDomain = Dictionary(
            (message.types["EIP712Domain"] ?? []).map { ($0.name, $0.type) },
            uniquingKeysWith: { first, _ in first }
        )
        var verifyingContract: Data?
        if declaredDomain["verifyingContract"] == "address",
           let contract = (hashedDomain["verifyingContract"] as? String).flatMap({ try? Data(hexStringSSF: $0) }),
           contract.count == EthereumConstants.accountIdLength {
            verifyingContract = contract
        }
        let domainName: String? = declaredDomain["name"] == "string" ? hashedDomain["name"] as? String : nil

        let fields: [WalletConnectTypedDataField]
        do {
            fields = try WalletConnectTypedDataFields.flatten(
                domain: hashedDomain,
                message: hashedMessage,
                types: message.types,
                primaryType: message.primaryType
            )
        } catch {
            // Too large to show in full, or a value the hash would read differently from how it is shown.
            throw WalletConnectRequestError.unsupported
        }

        return WalletConnectTypedData(
            signingInput: signingInput,
            primaryType: message.primaryType,
            domainName: domainName,
            verifyingContract: verifyingContract,
            allowance: WalletConnectTokenAllowance(
                primaryType: message.primaryType,
                message: hashedMessage,
                types: message.types,
                verifyingContract: verifyingContract
            ),
            fields: fields,
            // Without a chain id in the domain the signature names no network.
            isChainUnbound: domain["chainId"] == nil,
            unsignedKeys: WalletConnectTypedDataFields.undeclaredKeys(
                domain: domain,
                message: hashedMessage,
                types: message.types,
                primaryType: message.primaryType
            )
        )
    }
}

/// The signed fields of typed data, flattened for the confirmation in the order their types declare them. Only
/// declared fields are shown, because only they are hashed into the signature. Nothing is cut: typed data with more
/// fields or deeper nesting than the confirmation shows is declined, and so is a value whose shape differs from its
/// declared type (the hash reads a struct that is not an object as empty, and a lone value as a one-item array).
enum WalletConnectTypedDataFields {
    static let limit = 500
    static let maxDepth = 10

    enum Problem: Error, Equatable {
        case tooLarge
        case shapeMismatch(path: String)
    }

    static func flatten(
        domain: [String: Any],
        message: [String: Any],
        types: MessageTypes,
        primaryType: String
    ) throws -> [WalletConnectTypedDataField] {
        var fields: [WalletConnectTypedDataField] = []
        try append(object: domain, type: "EIP712Domain", path: "domain", types: types, into: &fields, depth: 0)
        if primaryType != "EIP712Domain" {
            try append(object: message, type: primaryType, path: "message", types: types, into: &fields, depth: 0)
        }
        return fields
    }

    /// Keys the typed data carries that its types do not declare, in the domain and at every level of the message:
    /// the signature does not cover them, so they are not shown.
    static func undeclaredKeys(
        domain: [String: Any],
        message: [String: Any],
        types: MessageTypes,
        primaryType: String
    ) -> [String] {
        var keys: [String] = []
        collectUndeclared(object: domain, type: "EIP712Domain", path: "domain", types: types, into: &keys, depth: 0)
        if primaryType != "EIP712Domain" {
            collectUndeclared(object: message, type: primaryType, path: "message", types: types, into: &keys, depth: 0)
        }
        return keys
    }

    private static func append(
        object: [String: Any],
        type: String,
        path: String,
        types: MessageTypes,
        into fields: inout [WalletConnectTypedDataField],
        depth: Int
    ) throws {
        guard let properties = types[type] else {
            return
        }
        guard depth <= maxDepth else {
            throw Problem.tooLarge
        }
        for property in properties {
            guard let value = object[property.name] else {
                continue
            }
            try append(
                value: value,
                type: property.type,
                path: "\(path).\(property.name)",
                types: types,
                into: &fields,
                depth: depth + 1
            )
        }
    }

    private static func append(
        value: Any,
        type: String,
        path: String,
        types: MessageTypes,
        into fields: inout [WalletConnectTypedDataField],
        depth: Int
    ) throws {
        guard depth <= maxDepth else {
            throw Problem.tooLarge
        }
        if type.hasSuffix("]"), let bracket = type.lastIndex(of: "[") {
            guard let items = value as? [Any] else {
                throw Problem.shapeMismatch(path: path)
            }
            let itemType = String(type[..<bracket])
            for (index, item) in items.enumerated() {
                try append(
                    value: item,
                    type: itemType,
                    path: "\(path)[\(index)]",
                    types: types,
                    into: &fields,
                    depth: depth + 1
                )
            }
            return
        }
        if types[type] != nil {
            guard let nested = value as? [String: Any] else {
                throw Problem.shapeMismatch(path: path)
            }
            try append(object: nested, type: type, path: path, types: types, into: &fields, depth: depth)
            return
        }
        guard fields.count < limit else {
            throw Problem.tooLarge
        }
        fields.append(WalletConnectTypedDataField(path: path, value: text(of: value)))
    }

    private static func collectUndeclared(
        object: [String: Any],
        type: String,
        path: String,
        types: MessageTypes,
        into keys: inout [String],
        depth: Int
    ) {
        guard let properties = types[type], depth <= maxDepth else {
            return
        }
        let declared = Dictionary(properties.map { ($0.name, $0.type) }, uniquingKeysWith: { first, _ in first })
        for (key, value) in object.sorted(by: { $0.key < $1.key }) {
            guard let propertyType = declared[key] else {
                keys.append("\(path).\(key)")
                continue
            }
            collectUndeclared(
                value: value,
                type: propertyType,
                path: "\(path).\(key)",
                types: types,
                into: &keys,
                depth: depth + 1
            )
        }
    }

    private static func collectUndeclared(
        value: Any,
        type: String,
        path: String,
        types: MessageTypes,
        into keys: inout [String],
        depth: Int
    ) {
        if type.hasSuffix("]"), let bracket = type.lastIndex(of: "["), let items = value as? [Any] {
            let itemType = String(type[..<bracket])
            for (index, item) in items.enumerated() {
                collectUndeclared(
                    value: item,
                    type: itemType,
                    path: "\(path)[\(index)]",
                    types: types,
                    into: &keys,
                    depth: depth + 1
                )
            }
        } else if types[type] != nil, let nested = value as? [String: Any] {
            collectUndeclared(object: nested, type: type, path: path, types: types, into: &keys, depth: depth)
        }
    }

    /// Numbers are written out in full: a JSON number may be beyond what `Double` holds exactly.
    static func text(of value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return NSDecimalNumber(decimal: number.decimalValue).stringValue
        default:
            guard
                JSONSerialization.isValidJSONObject(value),
                let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                let text = String(data: data, encoding: .utf8)
            else {
                return String(describing: value)
            }
            return text
        }
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
    private static let transferFromSelector = Data([0x23, 0xB8, 0x72, 0xDD])
    private static let approveSelector = Data([0x09, 0x5E, 0xA7, 0xB3])
    private static let increaseAllowanceSelector = Data([0x39, 0x50, 0x93, 0x51])
    private static let setApprovalForAllSelector = Data([0xA2, 0x2C, 0xB4, 0x65])

    /// Decodes `transfer`, `transferFrom`, `approve`, `increaseAllowance` and `setApprovalForAll`. Calldata longer
    /// than the call's arguments is decoded too, with the extra bytes counted, since a contract reads the arguments
    /// and ignores the rest. An address word with high bits set or a bool other than 0 or 1 is not decoded: a
    /// contract may read it differently from what the wallet would show.
    static func decode(_ data: Data) -> (call: WalletConnectTokenCall, trailingBytes: Int)? {
        guard data.count >= 4 else {
            return nil
        }
        let selector = Data(data.prefix(4))
        let arguments: Int
        switch selector {
        case transferSelector, approveSelector, increaseAllowanceSelector, setApprovalForAllSelector:
            arguments = 2
        case transferFromSelector:
            arguments = 3
        default:
            return nil
        }

        let length = 4 + 32 * arguments
        guard data.count >= length else {
            return nil
        }
        let words = (0 ..< arguments).map { index in
            Data(data.subdata(in: data.startIndex + 4 + 32 * index ..< data.startIndex + 4 + 32 * (index + 1)))
        }

        let call: WalletConnectTokenCall
        switch selector {
        case transferSelector:
            guard let recipient = address(words[0]) else { return nil }
            call = .transfer(recipient: recipient, amount: BigUInt(words[1]))
        case approveSelector:
            guard let spender = address(words[0]) else { return nil }
            call = .approve(spender: spender, amount: BigUInt(words[1]))
        case increaseAllowanceSelector:
            guard let spender = address(words[0]) else { return nil }
            call = .increaseAllowance(spender: spender, amount: BigUInt(words[1]))
        case setApprovalForAllSelector:
            guard let operatorAddress = address(words[0]), let approved = bool(words[1]) else { return nil }
            call = .setApprovalForAll(operator: operatorAddress, approved: approved)
        default:
            guard let owner = address(words[0]), let recipient = address(words[1]) else { return nil }
            call = .transferFrom(owner: owner, recipient: recipient, amountOrId: BigUInt(words[2]))
        }
        return (call, data.count - length)
    }

    private static func address(_ word: Data) -> Data? {
        guard word.prefix(12).allSatisfy({ $0 == 0 }) else {
            return nil
        }
        return Data(word.suffix(20))
    }

    private static func bool(_ word: Data) -> Bool? {
        guard word.prefix(31).allSatisfy({ $0 == 0 }), let last = word.last, last <= 1 else {
            return nil
        }
        return last == 1
    }
}

extension WalletConnectTokenAllowance {
    private static let unlimited = BigUInt(2).power(256) - 1

    /// The struct definitions, as EIP-712 encodes them, of the permits the wallet reads. Typed data whose primary
    /// type is defined in any other way is not read as a permit, so nothing the types do not declare can change
    /// what the confirmation says.
    static let eip2612Permit = "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    static let daiPermit = "Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)"
    static let permit2Single = "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)"
        + "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    static let permit2TransferFrom = "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,"
        + "uint256 deadline)TokenPermissions(address token,uint256 amount)"

    /// Reads the spender, the amount and how long it lasts from EIP-2612 `Permit`, DAI's `Permit` (`allowed`,
    /// `expiry`) and Permit2 `PermitSingle` and `PermitTransferFrom`, each only when the types define it exactly so.
    /// A permit whose amount the wallet cannot read exactly still names its spender; the amount is then `nil`.
    init?(primaryType: String, message: [String: AnyObject], types: MessageTypes, verifyingContract: Data?) {
        guard let definition = try? encodedType(primaryType: primaryType, types: types) else {
            return nil
        }

        let token: Data?
        let amount: BigUInt?
        let deadline: BigUInt?

        switch definition {
        case Self.daiPermit:
            // DAI: `allowed: true` is the unlimited allowance, `false` withdraws it.
            token = verifyingContract
            amount = Self.bool(from: message["allowed"]).map { $0 ? Self.unlimited : 0 }
            deadline = message["expiry"].flatMap { Self.amount(from: $0) }
        case Self.eip2612Permit:
            token = verifyingContract
            amount = message["value"].flatMap { Self.amount(from: $0) }
            deadline = message["deadline"].flatMap { Self.amount(from: $0) }
        case Self.permit2Single:
            let details = message["details"] as? [String: AnyObject]
            token = (details?["token"] as? String).flatMap { try? Data(hexStringSSF: $0) }
            amount = details?["amount"].flatMap { Self.amount(from: $0) }
            // How long the spender may use the allowance.
            deadline = details?["expiration"].flatMap { Self.amount(from: $0) }
        case Self.permit2TransferFrom:
            let permitted = message["permitted"] as? [String: AnyObject]
            token = (permitted?["token"] as? String).flatMap { try? Data(hexStringSSF: $0) }
            amount = permitted?["amount"].flatMap { Self.amount(from: $0) }
            deadline = message["deadline"].flatMap { Self.amount(from: $0) }
        default:
            return nil
        }

        guard
            let token = token,
            token.count == EthereumConstants.accountIdLength,
            let spender = (message["spender"] as? String).flatMap({ try? Data(hexStringSSF: $0) }),
            spender.count == EthereumConstants.accountIdLength
        else {
            return nil
        }

        self.init(token: token, spender: spender, amount: amount, deadline: deadline)
    }

    /// A JSON `true` or `false`, or the numbers 1 and 0, which the hash reads as the same bools.
    static func bool(from value: AnyObject?) -> Bool? {
        guard let number = value as? NSNumber, !(number is NSDecimalNumber), !CFNumberIsFloatType(number as CFNumber) else {
            return nil
        }
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue
        }
        switch number.int64Value {
        case 0:
            return false
        case 1:
            return true
        default:
            return nil
        }
    }

    /// Decimal or `0x` strings, and JSON integers. A JSON number with a fraction or beyond 64 bits is not read: the
    /// parser has already rounded it, so the amount shown might not be the one signed.
    static func amount(from value: AnyObject) -> BigUInt? {
        if let string = value as? String {
            return WalletConnectEthereumChainId.parse(string)
        }
        guard
            let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            !(number is NSDecimalNumber),
            !CFNumberIsFloatType(number as CFNumber)
        else {
            return nil
        }
        let text = number.stringValue
        guard !text.isEmpty, text.allSatisfy({ ("0" ... "9").contains($0) }) else {
            return nil
        }
        return BigUInt(text, radix: 10)
    }
}
