import Foundation

enum SolanaTransactionSignerError: Error, Equatable {
    case emptyTransaction
    case invalidTransactionBase64
    case invalidSignatureCount
    case missingSignatureSlot
    case truncatedSignatures
    case missingMessage
    case unsupportedTransactionVersion
    case malformedMessageHeader
    case invalidAccountKeys
    case invalidRequiredSignatureCount
    case truncatedAccountKeys
    case truncatedRecentBlockhash
    case invalidInstructionCount
    case truncatedInstructionProgram
    case invalidInstructionAccounts
    case truncatedInstructionAccounts
    case invalidInstructionData
    case truncatedInstructionData
    case invalidAddressTableLookups
    case truncatedAddressTableLookup
    case invalidAddressTableWritableIndexes
    case truncatedAddressTableWritableIndexes
    case invalidAddressTableReadonlyIndexes
    case truncatedAddressTableReadonlyIndexes
    case trailingMessageBytes
    case missingRequiredSignatureSlots
    case signerMismatch
    case invalidSignature
    case signatureMismatch
    case signerNotFound
    case signerNotRequired
}

enum SolanaTransactionVersion: Equatable {
    case legacy
    case v0
}

struct ParsedSolanaTransaction: Equatable {
    let accountKeys: [String]
    let accountKeyBytes: [Data]
    let addressTableLookupCount: Int
    let instructionCount: Int
    let firstInstructionProgramIndex: Int?
    let firstInstructionData: Data?
    let messageBytes: Data
    let messageOffset: Int
    let readonlySignedAccounts: Int
    let readonlyUnsignedAccounts: Int
    let recentBlockhash: String
    let requiredSignatures: Int
    let signatureCount: Int
    let signaturesOffset: Int
    let version: SolanaTransactionVersion
}

struct SignedSolanaTransaction: Equatable {
    let requiredSignatures: Int
    let signedTransaction: Data
    let signedTransactionBase64: String
    let signatureBase58: String
    let signer: String
    let version: SolanaTransactionVersion
}
