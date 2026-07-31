import CryptoKit
import Foundation
import TonSwift

enum TonTransferFeeQuoteError: Error, Equatable {
    case invalidVersion
    case invalidEndpoint
    case invalidTiming
    case invalidBinding
    case invalidFee
}

/// A short-lived, immutable confirmation quote for one exact native TON transfer template.
///
/// The quote binds the user-visible fee to the canonical unsigned Wallet V4R2 signing
/// payload. A signed submission must reproduce that payload byte-for-byte and signed
/// emulation must return the exact quoted fee before the app may broadcast.
struct TonTransferFeeQuote: Equatable, Sendable {
    static let currentVersion: UInt8 = 1
    static let maximumAgeSeconds: UInt64 = 30
    static let transportContract = "tonapi-swift-0.1.7"

    let version: UInt8
    let quoteIDHex: String
    let templateCreatedAt: UInt64
    let issuedAt: UInt64
    let expiresAt: UInt64
    let endpointOrigin: String
    let publicKey: Data
    let identity: TonTransferIntentIdentity
    let intent: TonEmulationIntent
    let transactionRequest: TonTransferTransactionRequest
    let walletState: TonWalletRemoteState
    let unsignedMessage: TonUnsignedEmulationMessage
    let feeNanotons: UInt64

    init(
        version: UInt8 = TonTransferFeeQuote.currentVersion,
        expectedQuoteIDHex: String? = nil,
        templateCreatedAt: UInt64,
        issuedAt: UInt64,
        expiresAt: UInt64,
        endpointOrigin: String,
        publicKey: Data,
        identity: TonTransferIntentIdentity,
        intent: TonEmulationIntent,
        transactionRequest: TonTransferTransactionRequest,
        walletState: TonWalletRemoteState,
        unsignedMessage: TonUnsignedEmulationMessage,
        feeNanotons: UInt64
    ) throws {
        guard version == Self.currentVersion else {
            throw TonTransferFeeQuoteError.invalidVersion
        }
        guard let endpointURL = URL(string: endpointOrigin),
              endpointURL.absoluteString == endpointOrigin,
              TonAPIClientFactory.isReviewedProductionSendServerURL(endpointURL)
        else {
            throw TonTransferFeeQuoteError.invalidEndpoint
        }
        guard templateCreatedAt <= issuedAt,
              issuedAt < expiresAt,
              expiresAt - issuedAt <= Self.maximumAgeSeconds,
              expiresAt < transactionRequest.validUntil,
              transactionRequest.validUntil - expiresAt >= TonTransferTransactionBuilder.minimumLifetimeSeconds,
              transactionRequest.validUntil - templateCreatedAt >= TonTransferTransactionBuilder.minimumLifetimeSeconds,
              transactionRequest.validUntil - templateCreatedAt <= TonTransferTransactionBuilder.maximumLifetimeSeconds,
              transactionRequest.validUntil <= UInt64(UInt32.max)
        else {
            throw TonTransferFeeQuoteError.invalidTiming
        }
        guard feeNanotons > 0,
              feeNanotons <= TonSendService.defaultMaximumFeeNanotons
        else {
            throw TonTransferFeeQuoteError.invalidFee
        }
        guard publicKey.count == 32,
              publicKey.contains(where: { $0 != 0 }),
              unsignedMessage.publicKey == publicKey,
              unsignedMessage.bocBase64 == unsignedMessage.boc.base64EncodedString(),
              !unsignedMessage.boc.isEmpty,
              unsignedMessage.boc.count <= TonTransferTransactionBuilder.maximumBocBytes,
              transactionRequest.asset == .nativeTon,
              transactionRequest.network == .mainnet,
              transactionRequest.senderAddress == identity.sender,
              transactionRequest.recipientAddress == identity.recipient,
              transactionRequest.amountNanotons == identity.amountNanotons,
              transactionRequest.bounce == identity.bounce,
              transactionRequest.comment == identity.comment,
              intent.senderAddress == identity.sender,
              intent.recipientAddress == identity.recipient,
              intent.amountNanotons.description == identity.amountNanotons,
              intent.bounce == identity.bounce,
              intent.messageBodyHashHex == (try TonTransferTransactionBuilder.messageBodyHashHex(comment: identity.comment)),
              transactionRequest.sequenceNumber == walletState.sequenceNumber,
              transactionRequest.includeStateInit == !walletState.isInitialized,
              (try? TonSwift.Address.parse(unsignedMessage.walletAddress).toRaw()) == identity.sender,
              unsignedMessage.sequenceNumber == walletState.sequenceNumber,
              unsignedMessage.validUntil == transactionRequest.validUntil,
              unsignedMessage.includesStateInit == !walletState.isInitialized,
              Self.isLowercaseHash(unsignedMessage.messageHashHex),
              Self.isLowercaseHash(unsignedMessage.signingPayloadHashHex)
        else {
            throw TonTransferFeeQuoteError.invalidBinding
        }

        let computedQuoteID = TonTransferFeeQuoteBinding.quoteIDHex(
            version: version,
            templateCreatedAt: templateCreatedAt,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            endpointOrigin: endpointOrigin,
            publicKey: publicKey,
            identity: identity,
            intent: intent,
            transactionRequest: transactionRequest,
            walletState: walletState,
            unsignedMessage: unsignedMessage,
            feeNanotons: feeNanotons
        )
        if let expectedQuoteIDHex,
           expectedQuoteIDHex != computedQuoteID {
            throw TonTransferFeeQuoteError.invalidBinding
        }

        self.version = version
        quoteIDHex = computedQuoteID
        self.templateCreatedAt = templateCreatedAt
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.endpointOrigin = endpointOrigin
        self.publicKey = publicKey
        self.identity = identity
        self.intent = intent
        self.transactionRequest = transactionRequest
        self.walletState = walletState
        self.unsignedMessage = unsignedMessage
        self.feeNanotons = feeNanotons
    }

    func validate(at now: UInt64, endpointOrigin currentEndpointOrigin: String?) throws {
        guard currentEndpointOrigin == endpointOrigin else {
            throw TonTransferFeeQuoteError.invalidEndpoint
        }
        guard now >= issuedAt,
              now <= expiresAt,
              now < transactionRequest.validUntil,
              transactionRequest.validUntil - now >= TonTransferTransactionBuilder.minimumLifetimeSeconds
        else {
            throw TonTransferFeeQuoteError.invalidTiming
        }
        _ = try TonTransferFeeQuote(
            version: version,
            expectedQuoteIDHex: quoteIDHex,
            templateCreatedAt: templateCreatedAt,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            endpointOrigin: endpointOrigin,
            publicKey: publicKey,
            identity: identity,
            intent: intent,
            transactionRequest: transactionRequest,
            walletState: walletState,
            unsignedMessage: unsignedMessage,
            feeNanotons: feeNanotons
        )
    }

    private static func isLowercaseHash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { byte in
            (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
        }
    }
}

private enum TonTransferFeeQuoteBinding {
    private static let domain = Data("fearless.ton.fee-quote.v1\0".utf8)

    static func quoteIDHex(
        version: UInt8,
        templateCreatedAt: UInt64,
        issuedAt: UInt64,
        expiresAt: UInt64,
        endpointOrigin: String,
        publicKey: Data,
        identity: TonTransferIntentIdentity,
        intent: TonEmulationIntent,
        transactionRequest: TonTransferTransactionRequest,
        walletState: TonWalletRemoteState,
        unsignedMessage: TonUnsignedEmulationMessage,
        feeNanotons: UInt64
    ) -> String {
        var payload = domain
        payload.append(version)
        append(Self.transportContractData, to: &payload)
        append(endpointOrigin, to: &payload)
        append(publicKey, to: &payload)
        append("native-ton", to: &payload)
        append("mainnet", to: &payload)
        append(identity.sender, to: &payload)
        append(identity.recipient, to: &payload)
        append(identity.amountNanotons, to: &payload)
        payload.append(identity.bounce ? 1 : 0)
        if let comment = identity.comment {
            payload.append(1)
            append(comment, to: &payload)
        } else {
            payload.append(0)
        }
        append(intent.messageBodyHashHex, to: &payload)
        append(templateCreatedAt, to: &payload)
        append(issuedAt, to: &payload)
        append(expiresAt, to: &payload)
        append(transactionRequest.sequenceNumber, to: &payload)
        payload.append(walletState.isInitialized ? 1 : 0)
        payload.append(unsignedMessage.includesStateInit ? 1 : 0)
        append(transactionRequest.validUntil, to: &payload)
        append(unsignedMessage.messageHashHex, to: &payload)
        append(unsignedMessage.signingPayloadHashHex, to: &payload)
        append(Data(SHA256.hash(data: unsignedMessage.boc)), to: &payload)
        append(feeNanotons, to: &payload)
        return Data(SHA256.hash(data: payload)).map { String(format: "%02x", $0) }.joined()
    }

    private static var transportContractData: Data {
        Data(TonTransferFeeQuote.transportContract.utf8)
    }

    private static func append(_ value: String, to data: inout Data) {
        append(Data(value.utf8), to: &data)
    }

    private static func append(_ value: Data, to data: inout Data) {
        precondition(value.count <= Int(UInt32.max))
        append(UInt32(value.count), to: &data)
        data.append(value)
    }

    private static func append(_ value: UInt64, to data: inout Data) {
        data.append(contentsOf: (0 ..< 8).map { offset in
            UInt8(truncatingIfNeeded: value >> UInt64((7 - offset) * 8))
        })
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        data.append(contentsOf: (0 ..< 4).map { offset in
            UInt8(truncatingIfNeeded: value >> UInt32((3 - offset) * 8))
        })
    }
}
