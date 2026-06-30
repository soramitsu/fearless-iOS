import Foundation

struct UniversalWalletSigningRequest: Codable, Equatable {
    let requestId: String
    let accountId: String
    let ecosystem: String
    let chainId: String
    let origin: String
    let method: UniversalWalletSigningMethod
    let message: UniversalWalletSigningPayload?
    let transactionBase64: String?
    let transactionsBase64: [String]
    let createdAtMillis: Int64
    let expiresAtMillis: Int64?

    func validationErrors() -> Set<UniversalWalletSigningValidationError> {
        var errors = Set<UniversalWalletSigningValidationError>()
        UniversalWalletSigningContractValidator.validateEnvelope(
            requestId: requestId,
            accountId: accountId,
            ecosystem: ecosystem,
            chainId: chainId,
            origin: origin,
            createdAtMillis: createdAtMillis,
            expiresAtMillis: expiresAtMillis,
            errors: &errors
        )

        switch method {
        case .signMessage:
            if let message {
                errors.formUnion(message.validationErrors())
            } else {
                errors.insert(.messageRequired)
            }
            if transactionBase64 != nil || !transactionsBase64.isEmpty {
                errors.insert(.payloadNotAllowed)
            }
        case .signTransaction, .signAndSendTransaction:
            if !UniversalWalletSigningContractValidator.isBase64Payload(
                transactionBase64,
                maxLength: UniversalWalletSigningContractValidator.maxTransactionBase64Length
            ) {
                errors.insert(.transactionRequired)
            }
            if message != nil || !transactionsBase64.isEmpty {
                errors.insert(.payloadNotAllowed)
            }
        case .signAllTransactions:
            if transactionsBase64.isEmpty ||
                transactionsBase64.count > UniversalWalletSigningContractValidator.maxTransactionBatch {
                errors.insert(.invalidBatch)
            }
            if transactionsBase64.contains(where: {
                !UniversalWalletSigningContractValidator.isBase64Payload(
                    $0,
                    maxLength: UniversalWalletSigningContractValidator.maxTransactionBase64Length
                )
            }) {
                errors.insert(.invalidBase64)
            }
            if message != nil || transactionBase64 != nil {
                errors.insert(.payloadNotAllowed)
            }
        }

        return errors
    }
}

struct UniversalWalletSigningPayload: Codable, Equatable {
    let encoding: UniversalWalletSigningPayloadEncoding
    let value: String
    let display: UniversalWalletSigningDisplay

    func validationErrors() -> Set<UniversalWalletSigningValidationError> {
        var errors = Set<UniversalWalletSigningValidationError>()

        switch encoding {
        case .base64:
            if !UniversalWalletSigningContractValidator.isBase64Payload(
                value,
                maxLength: UniversalWalletSigningContractValidator.maxMessageBase64Length
            ) {
                errors.insert(.invalidBase64)
            }
        case .hex:
            if !UniversalWalletSigningContractValidator.isHexPayload(
                value,
                maxLength: UniversalWalletSigningContractValidator.maxMessageHexLength
            ) {
                errors.insert(.invalidHex)
            }
        case .utf8:
            if !UniversalWalletSigningContractValidator.isHumanText(
                value,
                maxLength: UniversalWalletSigningContractValidator.maxMessageTextLength
            ) {
                errors.insert(.invalidMessage)
            }
        }

        return errors
    }
}

struct UniversalWalletSigningResult: Codable, Equatable {
    let requestId: String
    let accountId: String
    let ecosystem: String
    let chainId: String
    let method: UniversalWalletSigningMethod
    let status: UniversalWalletSigningResultStatus
    let publicKey: String?
    let signatureHex: String?
    let signatureBase64: String?
    let signatureBase58: String?
    let signedTransactionBase64: String?
    let signedTransactionsBase64: [String]
    let transactionHash: String?
    let errorCode: String?
    let signedAtMillis: Int64

    func validationErrors() -> Set<UniversalWalletSigningValidationError> {
        var errors = Set<UniversalWalletSigningValidationError>()
        UniversalWalletSigningContractValidator.validateEnvelope(
            requestId: requestId,
            accountId: accountId,
            ecosystem: ecosystem,
            chainId: chainId,
            origin: "result",
            createdAtMillis: signedAtMillis,
            expiresAtMillis: nil,
            errors: &errors
        )

        if status == .approved {
            if let publicKey {
                if !UniversalWalletSigningContractValidator.isMachineText(publicKey, maxLength: 256) {
                    errors.insert(.invalidPublicKey)
                }
            } else {
                errors.insert(.publicKeyRequired)
            }
            validateApprovedPayload(errors: &errors)
            if errorCode != nil {
                errors.insert(.errorNotAllowed)
            }
        } else {
            if errorCode.map({ UniversalWalletSigningContractValidator.matches($0, #"^[a-z][a-z0-9_:-]{1,63}$"#) }) != true {
                errors.insert(.errorCodeRequired)
            }
            if publicKey != nil || signatureHex != nil || signatureBase64 != nil || signatureBase58 != nil ||
                signedTransactionBase64 != nil || !signedTransactionsBase64.isEmpty || transactionHash != nil {
                errors.insert(.signatureNotAllowed)
            }
        }

        return errors
    }

    private func validateApprovedPayload(errors: inout Set<UniversalWalletSigningValidationError>) {
        let hasSignature = signatureHex != nil || signatureBase64 != nil || signatureBase58 != nil

        if let signatureHex,
           !UniversalWalletSigningContractValidator.matches(signatureHex, #"^(?:[0-9a-f]{2}){32,130}$"#) {
            errors.insert(.invalidSignature)
        }
        if let signatureBase64,
           !UniversalWalletSigningContractValidator.isBase64Payload(signatureBase64, maxLength: 512) {
            errors.insert(.invalidSignature)
        }
        if let signatureBase58,
           !UniversalWalletSigningContractValidator.matches(signatureBase58, #"^[1-9A-HJ-NP-Za-km-z]{64,128}$"#) {
            errors.insert(.invalidSignature)
        }

        switch method {
        case .signMessage:
            if !hasSignature {
                errors.insert(.signatureRequired)
            }
            if signedTransactionBase64 != nil || !signedTransactionsBase64.isEmpty || transactionHash != nil {
                errors.insert(.payloadNotAllowed)
            }
        case .signTransaction:
            if !UniversalWalletSigningContractValidator.isBase64Payload(
                signedTransactionBase64,
                maxLength: UniversalWalletSigningContractValidator.maxTransactionBase64Length
            ) {
                errors.insert(.signedTransactionRequired)
            }
            if !signedTransactionsBase64.isEmpty || transactionHash != nil {
                errors.insert(.payloadNotAllowed)
            }
        case .signAndSendTransaction:
            if !UniversalWalletSigningContractValidator.isBase64Payload(
                signedTransactionBase64,
                maxLength: UniversalWalletSigningContractValidator.maxTransactionBase64Length
            ) {
                errors.insert(.signedTransactionRequired)
            }
            if !UniversalWalletSigningContractValidator.isMachineText(transactionHash ?? "", maxLength: 256) {
                errors.insert(.transactionHashRequired)
            }
            if !signedTransactionsBase64.isEmpty {
                errors.insert(.payloadNotAllowed)
            }
        case .signAllTransactions:
            if signedTransactionsBase64.isEmpty ||
                signedTransactionsBase64.count > UniversalWalletSigningContractValidator.maxTransactionBatch {
                errors.insert(.signedTransactionRequired)
            }
            if signedTransactionsBase64.contains(where: {
                !UniversalWalletSigningContractValidator.isBase64Payload(
                    $0,
                    maxLength: UniversalWalletSigningContractValidator.maxTransactionBase64Length
                )
            }) {
                errors.insert(.invalidBase64)
            }
            if signedTransactionBase64 != nil || transactionHash != nil {
                errors.insert(.payloadNotAllowed)
            }
        }
    }
}

enum UniversalWalletSigningMethod: String, Codable {
    case signMessage = "sign-message"
    case signTransaction = "sign-transaction"
    case signAndSendTransaction = "sign-and-send-transaction"
    case signAllTransactions = "sign-all-transactions"
}

enum UniversalWalletSigningPayloadEncoding: String, Codable {
    case base64
    case hex
    case utf8
}

enum UniversalWalletSigningDisplay: String, Codable {
    case raw
    case utf8
    case hex
}

enum UniversalWalletSigningResultStatus: String, Codable {
    case approved
    case rejected
    case failed
}

enum UniversalWalletSigningValidationError: String, Error, CaseIterable {
    case invalidRequestId
    case invalidAccountId
    case invalidEcosystem
    case invalidChainId
    case invalidOrigin
    case invalidTimestamp
    case messageRequired
    case transactionRequired
    case invalidBatch
    case invalidBase64
    case invalidHex
    case invalidMessage
    case payloadNotAllowed
    case publicKeyRequired
    case invalidPublicKey
    case signatureRequired
    case invalidSignature
    case signedTransactionRequired
    case transactionHashRequired
    case errorCodeRequired
    case errorNotAllowed
    case signatureNotAllowed
}

enum UniversalWalletSigningContractValidator {
    static let maxMessageTextLength = 64 * 1024
    static let maxMessageBase64Length = 88 * 1024
    static let maxMessageHexLength = 128 * 1024
    static let maxTransactionBase64Length = 352 * 1024
    static let maxTransactionBatch = 16

    static func validateEnvelope(
        requestId: String,
        accountId: String,
        ecosystem: String,
        chainId: String,
        origin: String,
        createdAtMillis: Int64,
        expiresAtMillis: Int64?,
        errors: inout Set<UniversalWalletSigningValidationError>
    ) {
        if !matches(requestId, #"^sign_[A-Za-z0-9_-]{16,64}$"#) {
            errors.insert(.invalidRequestId)
        }
        if !matches(accountId, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
            errors.insert(.invalidAccountId)
        }
        if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
            errors.insert(.invalidEcosystem)
        }
        if !matches(chainId, #"^[A-Za-z0-9._:-]{2,128}$"#) {
            errors.insert(.invalidChainId)
        }
        if !isMachineText(origin, maxLength: 512) {
            errors.insert(.invalidOrigin)
        }
        if createdAtMillis <= 0 || expiresAtMillis.map({ $0 <= createdAtMillis }) == true {
            errors.insert(.invalidTimestamp)
        }
    }

    static func isBase64Payload(_ value: String?, maxLength: Int) -> Bool {
        guard let value else {
            return false
        }

        return !value.isEmpty &&
            value.count <= maxLength &&
            matches(value, #"^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$"#)
    }

    static func isHexPayload(_ value: String, maxLength: Int) -> Bool {
        !value.isEmpty &&
            value.count <= maxLength &&
            matches(value, #"^(?:[0-9a-f]{2})+$"#)
    }

    static func isHumanText(_ value: String, maxLength: Int) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty &&
            normalized.count <= maxLength &&
            normalized.rangeOfCharacter(from: .controlCharacters) == nil
    }

    static func isMachineText(_ value: String, maxLength: Int) -> Bool {
        value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.isEmpty &&
            value.count <= maxLength &&
            value.unicodeScalars.allSatisfy { $0.value > 0x20 && $0.value != 0x7F }
    }

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
