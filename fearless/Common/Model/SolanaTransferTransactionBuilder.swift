import Foundation
import BigInt
import CryptoKit

enum SolanaTransferTransactionBuilder {
    static let systemProgramAddress = "11111111111111111111111111111111"
    static let splTokenProgramAddress = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let token2022ProgramAddress = "TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb"
    static let associatedTokenProgramAddress = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"

    private static let publicKeyBytes = 32
    private static let signatureBytes = 64
    private static let systemTransferInstruction: UInt32 = 2
    private static let tokenTransferCheckedInstruction: UInt8 = 12
    private static let maxExtraTokenAccounts = 32
    private static let programDerivedAddressMarker = Data("ProgramDerivedAddress".utf8)
    private static let ed25519Prime = (BigUInt(1) << 255) - BigUInt(19)
    private static let ed25519D = BigUInt("37095705934669439343138083508754565189542113879843219016388785533085940283555")
    private static let ed25519SqrtMinusOne = BigUInt("19681161376707505956807079304988542015446066515923890162744021073123829784752")
    private static let ed25519SqrtExponent = (((BigUInt(1) << 255) - BigUInt(19)) - BigUInt(5)) >> 3
    private static let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let base58Index = Dictionary(uniqueKeysWithValues: base58Alphabet.enumerated().map { ($0.element, $0.offset) })

    static func buildNativeTransfer(
        senderAddress: String,
        recipientAddress: String,
        lamports: Int64,
        recentBlockhash: String
    ) throws -> SolanaUnsignedTransferTransaction {
        try requireLamports(lamports)

        let normalizedSender = try normalizeSenderAddress(senderAddress)
        let normalizedRecipient = try normalizeRecipientAddress(recipientAddress)
        let normalizedBlockhash = try normalizeRecentBlockhash(recentBlockhash)
        let sender = try decodePublicKey(normalizedSender, error: .invalidSender)
        let recipient = try decodePublicKey(normalizedRecipient, error: .invalidRecipient)
        let systemProgram = try decodePublicKey(systemProgramAddress, error: .invalidSender)
        let blockhash = try decodePublicKey(normalizedBlockhash, error: .invalidRecentBlockhash)

        var message = Data([1, 0, 1])
        message.append(compactU16(3))
        message.append(sender)
        message.append(recipient)
        message.append(systemProgram)
        message.append(blockhash)
        message.append(compactU16(1))
        message.append(2)
        message.append(compactU16(2))
        message.append(contentsOf: [0, 1])

        var instructionData = littleEndian(systemTransferInstruction)
        instructionData.append(littleEndian(UInt64(lamports)))
        message.append(compactU16(instructionData.count))
        message.append(instructionData)

        let transaction = transactionWithSingleEmptySignature(message)

        return SolanaUnsignedTransferTransaction(
            lamports: lamports,
            message: message,
            messageBase64: message.base64EncodedString(),
            recentBlockhash: normalizedBlockhash,
            recipientAddress: normalizedRecipient,
            senderAddress: normalizedSender,
            transaction: transaction,
            transactionBase64: transaction.base64EncodedString()
        )
    }

    static func buildTokenTransferChecked(
        ownerAddress: String,
        sourceTokenAccount: String,
        destinationTokenAccount: String,
        mintAddress: String,
        rawAmount: Int64,
        decimals: Int,
        recentBlockhash: String,
        tokenProgram: SolanaTokenProgram = .splToken,
        extraAccounts: [SolanaTokenTransferExtraAccount] = []
    ) throws -> SolanaUnsignedTokenTransferTransaction {
        guard rawAmount > 0 else {
            throw SolanaTransferTransactionError.invalidTokenAmount
        }
        guard (0 ... 255).contains(decimals) else {
            throw SolanaTransferTransactionError.invalidTokenDecimals
        }
        guard extraAccounts.count <= maxExtraTokenAccounts else {
            throw SolanaTransferTransactionError.tooManyExtraAccounts
        }

        let normalizedOwner = try normalizePublicKey(ownerAddress, error: .invalidSender)
        let normalizedSource = try normalizePublicKey(sourceTokenAccount, error: .invalidSourceTokenAccount)
        let normalizedDestination = try normalizePublicKey(destinationTokenAccount, error: .invalidDestinationTokenAccount)
        let normalizedMint = try normalizePublicKey(mintAddress, error: .invalidMint)
        let normalizedProgram = try normalizePublicKey(tokenProgram.programAddress, error: .invalidTokenProgram)
        let normalizedBlockhash = try normalizeRecentBlockhash(recentBlockhash)
        let normalizedExtras = try extraAccounts.map {
            SolanaTokenTransferExtraAccount(
                address: try normalizePublicKey($0.address, error: .invalidExtraAccount),
                isWritable: $0.isWritable
            )
        }
        let allKeys = [
            normalizedOwner,
            normalizedSource,
            normalizedDestination,
            normalizedMint,
            normalizedProgram
        ] + normalizedExtras.map(\.address)
        guard Set(allKeys).count == allKeys.count else {
            throw SolanaTransferTransactionError.duplicateAccount
        }

        let writableExtras = normalizedExtras.filter(\.isWritable)
        let readonlyExtras = normalizedExtras.filter { !$0.isWritable }
        let accountKeys = [
            normalizedOwner,
            normalizedSource,
            normalizedDestination
        ] + writableExtras.map(\.address) + [
            normalizedMint,
            normalizedProgram
        ] + readonlyExtras.map(\.address)
        let accountIndex = Dictionary(uniqueKeysWithValues: accountKeys.enumerated().map { ($0.element, $0.offset) })
        let instructionAccounts = [
            accountIndex[normalizedSource]!,
            accountIndex[normalizedMint]!,
            accountIndex[normalizedDestination]!,
            accountIndex[normalizedOwner]!
        ] + normalizedExtras.map { accountIndex[$0.address]! }

        var instructionData = Data([tokenTransferCheckedInstruction])
        instructionData.append(littleEndian(UInt64(rawAmount)))
        instructionData.append(UInt8(decimals))

        var message = Data([1, 0, UInt8(2 + readonlyExtras.count)])
        message.append(compactU16(accountKeys.count))
        for accountKey in accountKeys {
            message.append(try decodePublicKey(accountKey, error: .invalidExtraAccount))
        }
        message.append(try decodePublicKey(normalizedBlockhash, error: .invalidRecentBlockhash))
        message.append(compactU16(1))
        message.append(UInt8(accountIndex[normalizedProgram]!))
        message.append(compactU16(instructionAccounts.count))
        message.append(contentsOf: instructionAccounts.map(UInt8.init))
        message.append(compactU16(instructionData.count))
        message.append(instructionData)

        let transaction = transactionWithSingleEmptySignature(message)

        return SolanaUnsignedTokenTransferTransaction(
            decimals: decimals,
            destinationTokenAccount: normalizedDestination,
            extraAccounts: normalizedExtras,
            message: message,
            messageBase64: message.base64EncodedString(),
            mintAddress: normalizedMint,
            ownerAddress: normalizedOwner,
            rawAmount: rawAmount,
            recentBlockhash: normalizedBlockhash,
            sourceTokenAccount: normalizedSource,
            tokenProgram: tokenProgram,
            transaction: transaction,
            transactionBase64: transaction.base64EncodedString()
        )
    }

    static func buildCreateAssociatedTokenAccount(
        fundingAddress: String,
        walletAddress: String,
        associatedTokenAccount: String? = nil,
        mintAddress: String,
        recentBlockhash: String,
        tokenProgram: SolanaTokenProgram = .splToken,
        instruction: SolanaAssociatedTokenAccountInstruction = .createIdempotent
    ) throws -> SolanaUnsignedAssociatedTokenAccountCreateTransaction {
        let normalizedFunding = try normalizePublicKey(fundingAddress, error: .invalidFundingAccount)
        let normalizedWallet = try normalizePublicKey(walletAddress, error: .invalidWallet)
        let normalizedMint = try normalizePublicKey(mintAddress, error: .invalidMint)
        let normalizedTokenProgram = try normalizePublicKey(tokenProgram.programAddress, error: .invalidTokenProgram)
        let normalizedAssociatedProgram = try normalizePublicKey(associatedTokenProgramAddress, error: .invalidAssociatedTokenProgram)
        let derivedAssociated = try deriveAssociatedTokenAccountAddress(
            walletAddress: normalizedWallet,
            mintAddress: normalizedMint,
            tokenProgramAddress: normalizedTokenProgram,
            associatedTokenProgramAddress: normalizedAssociatedProgram
        )
        let normalizedAssociated = try associatedTokenAccount.flatMap { value -> String? in
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            return try normalizePublicKey(value, error: .invalidAssociatedTokenAccount)
        } ?? derivedAssociated
        guard normalizedAssociated == derivedAssociated else {
            throw SolanaTransferTransactionError.invalidAssociatedTokenAccount
        }
        let normalizedBlockhash = try normalizeRecentBlockhash(recentBlockhash)

        if normalizedAssociated == normalizedFunding ||
            normalizedAssociated == normalizedWallet ||
            normalizedAssociated == normalizedMint ||
            normalizedAssociated == systemProgramAddress ||
            normalizedAssociated == normalizedTokenProgram ||
            normalizedAssociated == normalizedAssociatedProgram ||
            normalizedMint == normalizedWallet ||
            normalizedMint == normalizedTokenProgram ||
            normalizedMint == normalizedAssociatedProgram {
            throw SolanaTransferTransactionError.duplicateAccount
        }

        let readonlyAccounts = [
            normalizedWallet,
            normalizedMint,
            systemProgramAddress,
            normalizedTokenProgram,
            normalizedAssociatedProgram
        ].reduce(into: [String]()) { result, address in
            if address != normalizedFunding,
               address != normalizedAssociated,
               !result.contains(address) {
                result.append(address)
            }
        }
        let accountKeys = [normalizedFunding, normalizedAssociated] + readonlyAccounts
        let accountIndex = Dictionary(uniqueKeysWithValues: accountKeys.enumerated().map { ($0.element, $0.offset) })
        let instructionAccounts = [
            accountIndex[normalizedFunding]!,
            accountIndex[normalizedAssociated]!,
            accountIndex[normalizedWallet]!,
            accountIndex[normalizedMint]!,
            accountIndex[systemProgramAddress]!,
            accountIndex[normalizedTokenProgram]!
        ]

        var message = Data([1, 0, UInt8(readonlyAccounts.count)])
        message.append(compactU16(accountKeys.count))
        for accountKey in accountKeys {
            message.append(try decodePublicKey(accountKey, error: .invalidAssociatedTokenAccount))
        }
        message.append(try decodePublicKey(normalizedBlockhash, error: .invalidRecentBlockhash))
        message.append(compactU16(1))
        message.append(UInt8(accountIndex[normalizedAssociatedProgram]!))
        message.append(compactU16(instructionAccounts.count))
        message.append(contentsOf: instructionAccounts.map(UInt8.init))
        message.append(compactU16(1))
        message.append(instruction.discriminator)

        let transaction = transactionWithSingleEmptySignature(message)

        return SolanaUnsignedAssociatedTokenAccountCreateTransaction(
            associatedTokenAccount: normalizedAssociated,
            fundingAddress: normalizedFunding,
            instruction: instruction,
            message: message,
            messageBase64: message.base64EncodedString(),
            mintAddress: normalizedMint,
            recentBlockhash: normalizedBlockhash,
            tokenProgram: tokenProgram,
            transaction: transaction,
            transactionBase64: transaction.base64EncodedString(),
            walletAddress: normalizedWallet
        )
    }

    static func buildTokenSendChecked(
        ownerAddress: String,
        sourceTokenAccount: String,
        destinationTokenAccount: String? = nil,
        mintAddress: String,
        rawAmount: Int64,
        decimals: Int,
        recentBlockhash: String,
        tokenProgram: SolanaTokenProgram = .splToken,
        extraAccounts: [SolanaTokenTransferExtraAccount] = [],
        destinationWalletAddress: String? = nil,
        associatedTokenAccountInstruction: SolanaAssociatedTokenAccountInstruction = .createIdempotent
    ) throws -> SolanaUnsignedTokenSendTransaction {
        guard rawAmount > 0 else {
            throw SolanaTransferTransactionError.invalidTokenAmount
        }
        guard (0 ... 255).contains(decimals) else {
            throw SolanaTransferTransactionError.invalidTokenDecimals
        }
        guard extraAccounts.count <= maxExtraTokenAccounts else {
            throw SolanaTransferTransactionError.tooManyExtraAccounts
        }

        let normalizedOwner = try normalizePublicKey(ownerAddress, error: .invalidSender)
        let normalizedSource = try normalizePublicKey(sourceTokenAccount, error: .invalidSourceTokenAccount)
        let normalizedDestinationWallet = try destinationWalletAddress.map {
            try normalizePublicKey($0, error: .invalidWallet)
        }
        let normalizedMint = try normalizePublicKey(mintAddress, error: .invalidMint)
        let normalizedProgram = try normalizePublicKey(tokenProgram.programAddress, error: .invalidTokenProgram)
        let normalizedAssociatedProgram = try normalizePublicKey(associatedTokenProgramAddress, error: .invalidAssociatedTokenProgram)
        let derivedAssociated = try normalizedDestinationWallet.map {
            try deriveAssociatedTokenAccountAddress(
                walletAddress: $0,
                mintAddress: normalizedMint,
                tokenProgramAddress: normalizedProgram,
                associatedTokenProgramAddress: normalizedAssociatedProgram
            )
        }
        let normalizedDestination = try destinationTokenAccount.flatMap { value -> String? in
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            return try normalizePublicKey(value, error: .invalidDestinationTokenAccount)
        } ?? derivedAssociated
        guard let normalizedDestination else {
            throw SolanaTransferTransactionError.invalidDestinationTokenAccount
        }
        if let derivedAssociated, normalizedDestination != derivedAssociated {
            throw SolanaTransferTransactionError.invalidAssociatedTokenAccount
        }
        let normalizedBlockhash = try normalizeRecentBlockhash(recentBlockhash)
        let normalizedExtras = try extraAccounts.map {
            SolanaTokenTransferExtraAccount(
                address: try normalizePublicKey($0.address, error: .invalidExtraAccount),
                isWritable: $0.isWritable
            )
        }

        var uniqueRoleKeys = [
            normalizedOwner,
            normalizedSource,
            normalizedDestination
        ]
        if let normalizedDestinationWallet, normalizedDestinationWallet != normalizedOwner {
            uniqueRoleKeys.append(normalizedDestinationWallet)
        }
        uniqueRoleKeys.append(normalizedMint)
        if normalizedDestinationWallet != nil {
            uniqueRoleKeys.append(systemProgramAddress)
        }
        uniqueRoleKeys.append(normalizedProgram)
        if normalizedDestinationWallet != nil {
            uniqueRoleKeys.append(normalizedAssociatedProgram)
        }
        uniqueRoleKeys.append(contentsOf: normalizedExtras.map(\.address))
        guard Set(uniqueRoleKeys).count == uniqueRoleKeys.count else {
            throw SolanaTransferTransactionError.duplicateAccount
        }

        let writableExtras = normalizedExtras.filter(\.isWritable)
        let readonlyExtras = normalizedExtras.filter { !$0.isWritable }
        let unsignedWritableAccounts = [
            normalizedSource,
            normalizedDestination
        ] + writableExtras.map(\.address)
        var unsignedReadonlyAccounts: [String] = []
        if let normalizedDestinationWallet, normalizedDestinationWallet != normalizedOwner {
            unsignedReadonlyAccounts.append(normalizedDestinationWallet)
        }
        unsignedReadonlyAccounts.append(normalizedMint)
        if normalizedDestinationWallet != nil {
            unsignedReadonlyAccounts.append(systemProgramAddress)
        }
        unsignedReadonlyAccounts.append(normalizedProgram)
        if normalizedDestinationWallet != nil {
            unsignedReadonlyAccounts.append(normalizedAssociatedProgram)
        }
        unsignedReadonlyAccounts.append(contentsOf: readonlyExtras.map(\.address))

        let accountKeys = [normalizedOwner] + unsignedWritableAccounts + unsignedReadonlyAccounts
        let accountIndex = Dictionary(uniqueKeysWithValues: accountKeys.enumerated().map { ($0.element, $0.offset) })
        var instructions: [CompiledSolanaInstruction] = []

        if let normalizedDestinationWallet {
            instructions.append(
                CompiledSolanaInstruction(
                    programAddress: normalizedAssociatedProgram,
                    accountAddresses: [
                        normalizedOwner,
                        normalizedDestination,
                        normalizedDestinationWallet,
                        normalizedMint,
                        systemProgramAddress,
                        normalizedProgram
                    ],
                    data: Data([associatedTokenAccountInstruction.discriminator])
                )
            )
        }

        var transferData = Data([tokenTransferCheckedInstruction])
        transferData.append(littleEndian(UInt64(rawAmount)))
        transferData.append(UInt8(decimals))
        instructions.append(
            CompiledSolanaInstruction(
                programAddress: normalizedProgram,
                accountAddresses: [
                    normalizedSource,
                    normalizedMint,
                    normalizedDestination,
                    normalizedOwner
                ] + normalizedExtras.map(\.address),
                data: transferData
            )
        )

        var message = Data([1, 0, UInt8(unsignedReadonlyAccounts.count)])
        message.append(compactU16(accountKeys.count))
        for accountKey in accountKeys {
            message.append(try decodePublicKey(accountKey, error: .invalidExtraAccount))
        }
        message.append(try decodePublicKey(normalizedBlockhash, error: .invalidRecentBlockhash))
        message.append(compactU16(instructions.count))
        for instruction in instructions {
            message.append(UInt8(accountIndex[instruction.programAddress]!))
            message.append(compactU16(instruction.accountAddresses.count))
            message.append(contentsOf: instruction.accountAddresses.map { UInt8(accountIndex[$0]!) })
            message.append(compactU16(instruction.data.count))
            message.append(instruction.data)
        }

        let transaction = transactionWithSingleEmptySignature(message)

        return SolanaUnsignedTokenSendTransaction(
            createsDestinationAssociatedTokenAccount: normalizedDestinationWallet != nil,
            decimals: decimals,
            destinationTokenAccount: normalizedDestination,
            destinationWalletAddress: normalizedDestinationWallet,
            extraAccounts: normalizedExtras,
            message: message,
            messageBase64: message.base64EncodedString(),
            mintAddress: normalizedMint,
            ownerAddress: normalizedOwner,
            rawAmount: rawAmount,
            recentBlockhash: normalizedBlockhash,
            sourceTokenAccount: normalizedSource,
            tokenProgram: tokenProgram,
            transaction: transaction,
            transactionBase64: transaction.base64EncodedString()
        )
    }

    static func deriveAssociatedTokenAccountAddress(
        walletAddress: String,
        mintAddress: String,
        tokenProgram: SolanaTokenProgram = .splToken
    ) throws -> String {
        let normalizedWallet = try normalizePublicKey(walletAddress, error: .invalidWallet)
        let normalizedMint = try normalizePublicKey(mintAddress, error: .invalidMint)
        let normalizedTokenProgram = try normalizePublicKey(tokenProgram.programAddress, error: .invalidTokenProgram)
        let normalizedAssociatedProgram = try normalizePublicKey(associatedTokenProgramAddress, error: .invalidAssociatedTokenProgram)

        return try deriveAssociatedTokenAccountAddress(
            walletAddress: normalizedWallet,
            mintAddress: normalizedMint,
            tokenProgramAddress: normalizedTokenProgram,
            associatedTokenProgramAddress: normalizedAssociatedProgram
        )
    }

    @discardableResult
    static func requireLamports(_ lamports: Int64) throws -> Int64 {
        guard lamports > 0 else {
            throw SolanaTransferTransactionError.invalidLamports
        }

        return lamports
    }

    static func normalizeSenderAddress(_ senderAddress: String) throws -> String {
        try normalizePublicKey(senderAddress, error: .invalidSender)
    }

    static func normalizeRecipientAddress(_ recipientAddress: String) throws -> String {
        try normalizePublicKey(recipientAddress, error: .invalidRecipient)
    }

    static func normalizeRecentBlockhash(_ recentBlockhash: String) throws -> String {
        try normalizePublicKey(recentBlockhash, error: .invalidRecentBlockhash)
    }

    private static func normalizePublicKey(_ value: String, error: SolanaTransferTransactionError) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try decodePublicKey(normalized, error: error)

        return normalized
    }

    private static func decodePublicKey(_ value: String, error: SolanaTransferTransactionError) throws -> Data {
        let decoded = try base58Decode(value, error: error)
        guard decoded.count == publicKeyBytes else {
            throw error
        }

        return decoded
    }

    private static func deriveAssociatedTokenAccountAddress(
        walletAddress: String,
        mintAddress: String,
        tokenProgramAddress: String,
        associatedTokenProgramAddress: String
    ) throws -> String {
        let seeds = try [
            decodePublicKey(walletAddress, error: .invalidWallet),
            decodePublicKey(tokenProgramAddress, error: .invalidTokenProgram),
            decodePublicKey(mintAddress, error: .invalidMint)
        ]
        let programId = try decodePublicKey(associatedTokenProgramAddress, error: .invalidAssociatedTokenProgram)

        for bump in stride(from: 255, through: 0, by: -1) {
            guard let candidate = createProgramAddress(seeds: seeds + [Data([UInt8(bump)])], programId: programId) else {
                continue
            }

            return base58Encode(Array(candidate))
        }

        throw SolanaTransferTransactionError.invalidAssociatedTokenAccount
    }

    private static func createProgramAddress(seeds: [Data], programId: Data) -> Data? {
        var payload = Data()
        for seed in seeds {
            payload.append(seed)
        }
        payload.append(programId)
        payload.append(programDerivedAddressMarker)

        let candidate = Data(SHA256.hash(data: payload))
        return isOnEd25519Curve(candidate) ? nil : candidate
    }

    private static func isOnEd25519Curve(_ publicKey: Data) -> Bool {
        guard publicKey.count == publicKeyBytes else {
            return false
        }

        var yBytes = Array(publicKey)
        yBytes[31] &= 0x7F
        let y = littleEndianBigUInt(yBytes)
        guard y < ed25519Prime else {
            return false
        }

        let ySquared = mod(y * y)
        let numerator = mod(ySquared + ed25519Prime - BigUInt(1))
        let denominator = mod(ed25519D * ySquared + BigUInt(1))

        return sqrtRatioM1(numerator, denominator) != nil
    }

    private static func sqrtRatioM1(_ numerator: BigUInt, _ denominator: BigUInt) -> BigUInt? {
        let denominatorSquared = mod(denominator * denominator)
        let denominatorCubed = mod(denominatorSquared * denominator)
        let denominatorSeventh = mod(mod(denominatorCubed * denominatorCubed) * denominator)
        var x = mod(numerator * denominatorCubed)
        x = mod(x * mod(mod(numerator * denominatorSeventh).power(ed25519SqrtExponent, modulus: ed25519Prime)))

        let check = mod(denominator * mod(x * x))
        if check == numerator {
            return x
        }
        if check == mod(ed25519Prime - numerator) {
            return mod(x * ed25519SqrtMinusOne)
        }

        return nil
    }

    private static func littleEndianBigUInt(_ bytes: [UInt8]) -> BigUInt {
        var result = BigUInt.zero
        for (index, byte) in bytes.enumerated() {
            result += BigUInt(byte) << (index * 8)
        }

        return result
    }

    private static func mod(_ value: BigUInt) -> BigUInt {
        value % ed25519Prime
    }

    private static func base58Encode(_ bytes: [UInt8]) -> String {
        guard !bytes.isEmpty else {
            return ""
        }

        var number = BigUInt(Data(bytes))
        let radix = BigUInt(base58Alphabet.count)
        var encoded = ""

        while number > 0 {
            let remainder = number % radix
            encoded.append(base58Alphabet[Int(remainder)])
            number /= radix
        }

        for _ in bytes.prefix(while: { $0 == 0 }) {
            encoded.append(base58Alphabet[0])
        }

        return String(encoded.reversed())
    }

    private static func base58Decode(_ value: String, error: SolanaTransferTransactionError) throws -> Data {
        guard !value.isEmpty else {
            throw error
        }

        var bytes: [Int] = []
        for character in value {
            guard var carry = base58Index[character] else {
                throw error
            }

            for index in bytes.indices {
                let next = bytes[index] * base58Alphabet.count + carry
                bytes[index] = next & 0xFF
                carry = next >> 8
            }

            while carry > 0 {
                bytes.append(carry & 0xFF)
                carry >>= 8
            }
        }

        let leadingZeroes = value.prefix { $0 == base58Alphabet[0] }.count
        return Data(repeating: 0, count: leadingZeroes) + Data(bytes.reversed().map(UInt8.init))
    }

    private static func compactU16(_ value: Int) -> Data {
        precondition((0 ... 0xFFFF).contains(value), "Compact-u16 value out of range")

        var result = Data()
        var next = value

        repeat {
            var byte = next & 0x7F
            next >>= 7
            if next > 0 {
                byte |= 0x80
            }
            result.append(UInt8(byte))
        } while next > 0

        return result
    }

    private static func littleEndian(_ value: UInt32) -> Data {
        var littleEndianValue = value.littleEndian
        return Data(bytes: &littleEndianValue, count: MemoryLayout<UInt32>.size)
    }

    private static func littleEndian(_ value: UInt64) -> Data {
        var littleEndianValue = value.littleEndian
        return Data(bytes: &littleEndianValue, count: MemoryLayout<UInt64>.size)
    }

    private static func transactionWithSingleEmptySignature(_ message: Data) -> Data {
        var transaction = compactU16(1)
        transaction.append(Data(repeating: 0, count: signatureBytes))
        transaction.append(message)

        return transaction
    }

    private struct CompiledSolanaInstruction {
        let programAddress: String
        let accountAddresses: [String]
        let data: Data
    }
}

struct SolanaUnsignedTransferTransaction: Equatable {
    let lamports: Int64
    let message: Data
    let messageBase64: String
    let recentBlockhash: String
    let recipientAddress: String
    let senderAddress: String
    let transaction: Data
    let transactionBase64: String
}

enum SolanaTokenProgram: Equatable {
    case splToken
    case token2022

    var programAddress: String {
        switch self {
        case .splToken:
            return SolanaTransferTransactionBuilder.splTokenProgramAddress
        case .token2022:
            return SolanaTransferTransactionBuilder.token2022ProgramAddress
        }
    }
}

enum SolanaAssociatedTokenAccountInstruction: Equatable {
    case create
    case createIdempotent

    var discriminator: UInt8 {
        switch self {
        case .create:
            return 0
        case .createIdempotent:
            return 1
        }
    }
}

struct SolanaTokenTransferExtraAccount: Equatable {
    let address: String
    let isWritable: Bool

    init(address: String, isWritable: Bool = false) {
        self.address = address
        self.isWritable = isWritable
    }
}

struct SolanaUnsignedTokenTransferTransaction: Equatable {
    let decimals: Int
    let destinationTokenAccount: String
    let extraAccounts: [SolanaTokenTransferExtraAccount]
    let message: Data
    let messageBase64: String
    let mintAddress: String
    let ownerAddress: String
    let rawAmount: Int64
    let recentBlockhash: String
    let sourceTokenAccount: String
    let tokenProgram: SolanaTokenProgram
    let transaction: Data
    let transactionBase64: String
}

struct SolanaUnsignedAssociatedTokenAccountCreateTransaction: Equatable {
    let associatedTokenAccount: String
    let fundingAddress: String
    let instruction: SolanaAssociatedTokenAccountInstruction
    let message: Data
    let messageBase64: String
    let mintAddress: String
    let recentBlockhash: String
    let tokenProgram: SolanaTokenProgram
    let transaction: Data
    let transactionBase64: String
    let walletAddress: String
}

struct SolanaUnsignedTokenSendTransaction: Equatable {
    let createsDestinationAssociatedTokenAccount: Bool
    let decimals: Int
    let destinationTokenAccount: String
    let destinationWalletAddress: String?
    let extraAccounts: [SolanaTokenTransferExtraAccount]
    let message: Data
    let messageBase64: String
    let mintAddress: String
    let ownerAddress: String
    let rawAmount: Int64
    let recentBlockhash: String
    let sourceTokenAccount: String
    let tokenProgram: SolanaTokenProgram
    let transaction: Data
    let transactionBase64: String
}

enum SolanaTransferTransactionError: Error, Equatable {
    case invalidSender
    case invalidRecipient
    case invalidRecentBlockhash
    case invalidLamports
    case invalidSourceTokenAccount
    case invalidDestinationTokenAccount
    case invalidMint
    case invalidTokenProgram
    case invalidTokenAmount
    case invalidTokenDecimals
    case invalidExtraAccount
    case tooManyExtraAccounts
    case duplicateAccount
    case invalidFundingAccount
    case invalidWallet
    case invalidAssociatedTokenAccount
    case invalidAssociatedTokenProgram
}
