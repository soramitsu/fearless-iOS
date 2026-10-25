import Foundation

enum SolanaTransactionSigner {
    private static let signatureBytes = 64
    private static let publicKeyBytes = 32
    private static let versionPrefixMask = 0x80
    private static let versionValueMask = 0x7F
    private static let maxCompactU16Bytes = 3
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func parseSerializedTransaction(_ transaction: Data) throws -> ParsedSolanaTransaction {
        guard !transaction.isEmpty else {
            throw SolanaTransactionSignerError.emptyTransaction
        }

        let signatureCount = try readCompactU16(transaction, offset: 0, error: .invalidSignatureCount)
        let signaturesOffset = signatureCount.offset
        let messageOffset = signaturesOffset + signatureCount.value * signatureBytes

        guard signatureCount.value >= 1 else {
            throw SolanaTransactionSignerError.missingSignatureSlot
        }

        try ensureAvailable(transaction, offset: signaturesOffset, length: signatureCount.value * signatureBytes, error: .truncatedSignatures)
        try ensureAvailable(transaction, offset: messageOffset, length: 1, error: .missingMessage)

        let messageBytes = transaction.subdata(in: messageOffset ..< transaction.count)
        let message = try parseMessage(messageBytes)

        guard signatureCount.value >= message.requiredSignatures else {
            throw SolanaTransactionSignerError.missingRequiredSignatureSlots
        }

        return ParsedSolanaTransaction(
            accountKeys: message.accountKeys,
            accountKeyBytes: message.accountKeyBytes,
            addressTableLookupCount: message.addressTableLookupCount,
            instructionCount: message.instructionCount,
            firstInstructionProgramIndex: message.firstInstructionProgramIndex,
            firstInstructionData: message.firstInstructionData,
            messageBytes: messageBytes,
            messageOffset: messageOffset,
            readonlySignedAccounts: message.readonlySignedAccounts,
            readonlyUnsignedAccounts: message.readonlyUnsignedAccounts,
            recentBlockhash: message.recentBlockhash,
            requiredSignatures: message.requiredSignatures,
            signatureCount: signatureCount.value,
            signaturesOffset: signaturesOffset,
            version: message.version
        )
    }

    static func parseSerializedTransaction(base64: String) throws -> ParsedSolanaTransaction {
        try parseSerializedTransaction(decodeBase64Transaction(base64))
    }

    /// Verifies the retained identity and every required signature without reading keys.
    /// Parsing alone is also used for unsigned transactions and cannot establish this.
    static func verifySerializedTransaction(
        base64: String,
        expectedSignature: String
    ) throws -> ParsedSolanaTransaction {
        let wire = try decodeBase64Transaction(base64)
        let parsed = try parseSerializedTransaction(wire)
        guard parsed.requiredSignatures > 0,
              parsed.signatureCount == parsed.requiredSignatures,
              parsed.readonlySignedAccounts < parsed.requiredSignatures else {
            throw SolanaTransactionSignerError.invalidRequiredSignatureCount
        }
        for index in 0 ..< parsed.requiredSignatures {
            let start = parsed.signaturesOffset + index * signatureBytes
            let signature = wire.subdata(in: start ..< start + signatureBytes)
            if index == 0, base58Encode(Array(signature)) != expectedSignature {
                throw SolanaTransactionSignerError.signatureMismatch
            }
            guard try SolanaSigner.verifyMessage(
                publicKey: parsed.accountKeyBytes[index],
                message: parsed.messageBytes,
                signature: signature
            ) else {
                throw SolanaTransactionSignerError.invalidSignature
            }
        }
        return parsed
    }

    static func signSerializedTransaction(
        mnemonic: String,
        transaction: Data,
        expectedSigner: String? = nil,
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault,
        passphrase: String = ""
    ) throws -> SignedSolanaTransaction {
        let parsed = try parseSerializedTransaction(transaction)
        let account = try SolanaKeyDerivation.deriveAccount(
            mnemonic: mnemonic,
            passphrase: passphrase,
            derivationPath: derivationPath
        )

        if let expectedSigner, expectedSigner != account.address {
            throw SolanaTransactionSignerError.signerMismatch
        }

        guard let signerIndex = parsed.accountKeys.firstIndex(of: account.address) else {
            throw SolanaTransactionSignerError.signerNotFound
        }

        guard signerIndex < parsed.requiredSignatures else {
            throw SolanaTransactionSignerError.signerNotRequired
        }

        guard signerIndex < parsed.signatureCount else {
            throw SolanaTransactionSignerError.missingSignatureSlot
        }

        let signature = try SolanaSigner.signMessage(privateKey: account.privateKey, message: parsed.messageBytes)
        var signedTransaction = transaction

        signedTransaction.replaceSubrange(
            parsed.signaturesOffset + signerIndex * signatureBytes ..< parsed.signaturesOffset + (signerIndex + 1) * signatureBytes,
            with: signature
        )

        return SignedSolanaTransaction(
            requiredSignatures: parsed.requiredSignatures,
            signedTransaction: signedTransaction,
            signedTransactionBase64: signedTransaction.base64EncodedString(),
            signatureBase58: base58Encode(Array(signature)),
            signer: account.address,
            version: parsed.version
        )
    }

    static func signSerializedTransaction(
        mnemonic: String,
        transactionBase64: String,
        expectedSigner: String? = nil,
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault,
        passphrase: String = ""
    ) throws -> SignedSolanaTransaction {
        try signSerializedTransaction(
            mnemonic: mnemonic,
            transaction: decodeBase64Transaction(transactionBase64),
            expectedSigner: expectedSigner,
            derivationPath: derivationPath,
            passphrase: passphrase
        )
    }

    private static func parseMessage(_ message: Data) throws -> ParsedSolanaTransaction {
        var offset = 0
        var version = SolanaTransactionVersion.legacy

        if (Int(message[offset]) & versionPrefixMask) != 0 {
            let versionValue = Int(message[offset]) & versionValueMask

            guard versionValue == 0 else {
                throw SolanaTransactionSignerError.unsupportedTransactionVersion
            }

            version = .v0
            offset += 1
        }

        try ensureAvailable(message, offset: offset, length: 3, error: .malformedMessageHeader)

        let requiredSignatures = Int(message[offset])
        let readonlySignedAccounts = Int(message[offset + 1])
        let readonlyUnsignedAccounts = Int(message[offset + 2])

        offset += 3

        let accountCount = try readCompactU16(message, offset: offset, error: .invalidAccountKeys)
        offset = accountCount.offset

        guard accountCount.value >= requiredSignatures else {
            throw SolanaTransactionSignerError.invalidRequiredSignatureCount
        }
        guard readonlySignedAccounts <= requiredSignatures else {
            throw SolanaTransactionSignerError.invalidRequiredSignatureCount
        }
        guard readonlyUnsignedAccounts <= accountCount.value - requiredSignatures else {
            throw SolanaTransactionSignerError.invalidRequiredSignatureCount
        }

        try ensureAvailable(message, offset: offset, length: accountCount.value * publicKeyBytes, error: .truncatedAccountKeys)

        var accountKeys: [String] = []
        var accountKeyBytes: [Data] = []
        for _ in 0 ..< accountCount.value {
            let publicKey = message.subdata(in: offset ..< offset + publicKeyBytes)
            accountKeyBytes.append(publicKey)
            accountKeys.append(base58Encode(Array(publicKey)))
            offset += publicKeyBytes
        }

        try ensureAvailable(message, offset: offset, length: publicKeyBytes, error: .truncatedRecentBlockhash)
        let recentBlockhash = base58Encode(Array(message[offset ..< offset + publicKeyBytes]))
        offset += publicKeyBytes

        let instructions = try skipCompiledInstructions(message, offset: offset)
        offset = instructions.offset

        var addressTableLookupCount = 0
        if version == .v0 {
            let lookups = try skipAddressTableLookups(message, offset: offset)
            addressTableLookupCount = lookups.count
            offset = lookups.offset
        }

        guard offset == message.count else {
            throw SolanaTransactionSignerError.trailingMessageBytes
        }

        return ParsedSolanaTransaction(
            accountKeys: accountKeys,
            accountKeyBytes: accountKeyBytes,
            addressTableLookupCount: addressTableLookupCount,
            instructionCount: instructions.count,
            firstInstructionProgramIndex: instructions.programIndex,
            firstInstructionData: instructions.data,
            messageBytes: Data(),
            messageOffset: 0,
            readonlySignedAccounts: readonlySignedAccounts,
            readonlyUnsignedAccounts: readonlyUnsignedAccounts,
            recentBlockhash: recentBlockhash,
            requiredSignatures: requiredSignatures,
            signatureCount: 0,
            signaturesOffset: 0,
            version: version
        )
    }

    private struct CompiledInstructions {
        let count: Int
        let offset: Int
        let programIndex: Int?
        let data: Data?
    }

    private static func skipCompiledInstructions(_ message: Data, offset: Int) throws -> CompiledInstructions {
        var offset = offset
        let instructionCount = try readCompactU16(message, offset: offset, error: .invalidInstructionCount)
        offset = instructionCount.offset

        var firstProgramIndex: Int?
        var firstData: Data?
        for index in 0 ..< instructionCount.value {
            try ensureAvailable(message, offset: offset, length: 1, error: .truncatedInstructionProgram)
            if index == 0 { firstProgramIndex = Int(message[offset]) }
            offset += 1

            let accountIndexCount = try readCompactU16(message, offset: offset, error: .invalidInstructionAccounts)
            offset = accountIndexCount.offset
            try ensureAvailable(message, offset: offset, length: accountIndexCount.value, error: .truncatedInstructionAccounts)
            offset += accountIndexCount.value

            let dataLength = try readCompactU16(message, offset: offset, error: .invalidInstructionData)
            offset = dataLength.offset
            try ensureAvailable(message, offset: offset, length: dataLength.value, error: .truncatedInstructionData)
            if index == 0 { firstData = message.subdata(in: offset ..< offset + dataLength.value) }
            offset += dataLength.value
        }

        return CompiledInstructions(
            count: instructionCount.value, offset: offset, programIndex: firstProgramIndex, data: firstData
        )
    }

    private static func skipAddressTableLookups(_ message: Data, offset: Int) throws -> (count: Int, offset: Int) {
        var offset = offset
        let lookupCount = try readCompactU16(message, offset: offset, error: .invalidAddressTableLookups)
        offset = lookupCount.offset

        for _ in 0 ..< lookupCount.value {
            try ensureAvailable(message, offset: offset, length: publicKeyBytes, error: .truncatedAddressTableLookup)
            offset += publicKeyBytes

            let writableCount = try readCompactU16(message, offset: offset, error: .invalidAddressTableWritableIndexes)
            offset = writableCount.offset
            try ensureAvailable(message, offset: offset, length: writableCount.value, error: .truncatedAddressTableWritableIndexes)
            offset += writableCount.value

            let readonlyCount = try readCompactU16(message, offset: offset, error: .invalidAddressTableReadonlyIndexes)
            offset = readonlyCount.offset
            try ensureAvailable(message, offset: offset, length: readonlyCount.value, error: .truncatedAddressTableReadonlyIndexes)
            offset += readonlyCount.value
        }

        return (lookupCount.value, offset)
    }

    private static func readCompactU16(
        _ bytes: Data,
        offset: Int,
        error: SolanaTransactionSignerError
    ) throws -> (value: Int, offset: Int) {
        var value = 0
        var shift = 0
        var offset = offset

        for _ in 0 ..< maxCompactU16Bytes {
            try ensureAvailable(bytes, offset: offset, length: 1, error: error)

            let byte = Int(bytes[offset])
            offset += 1
            value |= (byte & 0x7F) << shift

            if (byte & 0x80) == 0 {
                return (value, offset)
            }

            shift += 7
        }

        throw error
    }

    private static func ensureAvailable(
        _ bytes: Data,
        offset: Int,
        length: Int,
        error: SolanaTransactionSignerError
    ) throws {
        guard offset >= 0, length >= 0, offset + length <= bytes.count else {
            throw error
        }
    }

    private static func decodeBase64Transaction(_ transactionBase64: String) throws -> Data {
        guard !transactionBase64.isEmpty else {
            throw SolanaTransactionSignerError.emptyTransaction
        }

        guard transactionBase64.range(
            of: "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$",
            options: .regularExpression
        ) != nil else {
            throw SolanaTransactionSignerError.invalidTransactionBase64
        }

        guard let data = Data(base64Encoded: transactionBase64) else {
            throw SolanaTransactionSignerError.invalidTransactionBase64
        }

        return data
    }

    private static func base58Encode(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else {
            return ""
        }

        var digits: [Int] = []

        for byte in bytes {
            var carry = Int(byte)

            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % base58Alphabet.count
                carry = value / base58Alphabet.count
            }

            while carry > 0 {
                digits.append(carry % base58Alphabet.count)
                carry /= base58Alphabet.count
            }
        }

        var result = String(repeating: String(base58Alphabet[0]), count: bytes.prefix { $0 == 0 }.count)
        for digit in digits.reversed() {
            result.append(base58Alphabet[digit])
        }

        return result
    }
}
