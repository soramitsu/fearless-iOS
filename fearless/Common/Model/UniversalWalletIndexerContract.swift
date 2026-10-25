import Foundation

struct UniversalWalletIndexedAssetBalance: Codable, Equatable {
    let accountId: String
    let ecosystem: String
    let chainId: String
    let assetId: String
    let amount: String
    let decimals: Int
    let isNative: Bool
    let symbol: String?
    let name: String?
    let uiAmountString: String?
    let tokenAccountId: String?
    let contractAddress: String?
    let tokenProgram: String?
    let syncedAtMillis: Int64

    init(
        accountId: String,
        ecosystem: String,
        chainId: String,
        assetId: String,
        amount: String,
        decimals: Int,
        isNative: Bool,
        symbol: String? = nil,
        name: String? = nil,
        uiAmountString: String? = nil,
        tokenAccountId: String? = nil,
        contractAddress: String? = nil,
        tokenProgram: String? = nil,
        syncedAtMillis: Int64
    ) {
        self.accountId = accountId
        self.ecosystem = ecosystem
        self.chainId = chainId
        self.assetId = assetId
        self.amount = amount
        self.decimals = decimals
        self.isNative = isNative
        self.symbol = symbol
        self.name = name
        self.uiAmountString = uiAmountString
        self.tokenAccountId = tokenAccountId
        self.contractAddress = contractAddress
        self.tokenProgram = tokenProgram
        self.syncedAtMillis = syncedAtMillis
    }

    init(
        accountId: String,
        ecosystem: UniversalWalletEcosystem,
        chainId: String,
        assetId: String,
        amount: String,
        decimals: Int,
        isNative: Bool,
        symbol: String? = nil,
        name: String? = nil,
        uiAmountString: String? = nil,
        tokenAccountId: String? = nil,
        contractAddress: String? = nil,
        tokenProgram: String? = nil,
        syncedAtMillis: Int64
    ) {
        self.init(
            accountId: accountId,
            ecosystem: ecosystem.rawValue,
            chainId: chainId,
            assetId: assetId,
            amount: amount,
            decimals: decimals,
            isNative: isNative,
            symbol: symbol,
            name: name,
            uiAmountString: uiAmountString,
            tokenAccountId: tokenAccountId,
            contractAddress: contractAddress,
            tokenProgram: tokenProgram,
            syncedAtMillis: syncedAtMillis
        )
    }

    func validationErrors() -> Set<UniversalWalletIndexerValidationError> {
        var errors = Set<UniversalWalletIndexerValidationError>()
        UniversalWalletIndexerContractValidator.validateEnvelope(
            accountId: accountId,
            ecosystem: ecosystem,
            chainId: chainId,
            syncedAtMillis: syncedAtMillis,
            errors: &errors
        )
        if !UniversalWalletIndexerContractValidator.isMachineText(assetId, maxLength: 160) {
            errors.insert(.invalidAssetId)
        }
        if !UniversalWalletIndexerContractValidator.isUnsignedInteger(amount) {
            errors.insert(.invalidAmount)
        }
        if !UniversalWalletIndexerContractValidator.decimalRange.contains(decimals) {
            errors.insert(.invalidDecimals)
        }
        if let symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isHumanText(symbol, maxLength: 32) {
            errors.insert(.invalidSymbol)
        }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isHumanText(name, maxLength: 96) {
            errors.insert(.invalidName)
        }
        if let uiAmountString, !uiAmountString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isHumanText(uiAmountString, maxLength: 80) {
            errors.insert(.invalidAmount)
        }
        if let tokenAccountId, !tokenAccountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isMachineText(tokenAccountId, maxLength: 256) {
            errors.insert(.invalidAccountId)
        }
        if let contractAddress, !contractAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isMachineText(contractAddress, maxLength: 256) {
            errors.insert(.invalidAddress)
        }
        if let tokenProgram, !tokenProgram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isMachineText(tokenProgram, maxLength: 64) {
            errors.insert(.invalidAssetId)
        }

        return errors
    }
}

struct UniversalWalletIndexedTransaction: Codable, Equatable {
    let accountId: String
    let ecosystem: String
    let chainId: String
    let transactionId: String
    let status: UniversalWalletIndexedTransactionStatus
    let direction: UniversalWalletIndexedTransactionDirection
    let operationType: UniversalWalletIndexedOperationType
    let timestampMillis: Int64?
    let amount: String?
    let assetId: String?
    let feeAmount: String?
    let feeAssetId: String?
    let counterpartyAddress: String?
    let blockNumber: String?
    let cursor: String?
    let explorerUrl: String?
    let syncedAtMillis: Int64

    func validationErrors() -> Set<UniversalWalletIndexerValidationError> {
        var errors = Set<UniversalWalletIndexerValidationError>()
        UniversalWalletIndexerContractValidator.validateEnvelope(
            accountId: accountId,
            ecosystem: ecosystem,
            chainId: chainId,
            syncedAtMillis: syncedAtMillis,
            errors: &errors
        )
        if !UniversalWalletIndexerContractValidator.isMachineText(transactionId, maxLength: 256) {
            errors.insert(.invalidTransactionId)
        }
        if let timestampMillis, timestampMillis <= 0 {
            errors.insert(.invalidTimestamp)
        }
        if let amount, !UniversalWalletIndexerContractValidator.isUnsignedInteger(amount) {
            errors.insert(.invalidAmount)
        }
        if let assetId, !UniversalWalletIndexerContractValidator.isMachineText(assetId, maxLength: 160) {
            errors.insert(.invalidAssetId)
        }
        if let feeAmount, !UniversalWalletIndexerContractValidator.isUnsignedInteger(feeAmount) {
            errors.insert(.invalidAmount)
        }
        if let feeAssetId, !UniversalWalletIndexerContractValidator.isMachineText(feeAssetId, maxLength: 160) {
            errors.insert(.invalidAssetId)
        }
        if let counterpartyAddress, !UniversalWalletIndexerContractValidator.isMachineText(counterpartyAddress, maxLength: 256) {
            errors.insert(.invalidAddress)
        }
        if let blockNumber, !UniversalWalletIndexerContractValidator.isUnsignedInteger(blockNumber) {
            errors.insert(.invalidBlockNumber)
        }
        if let cursor, !UniversalWalletIndexerContractValidator.isMachineText(cursor, maxLength: 512) {
            errors.insert(.invalidCursor)
        }
        if let explorerUrl, !UniversalWalletIndexerContractValidator.isHttpsUrl(explorerUrl) {
            errors.insert(.invalidUrl)
        }

        return errors
    }
}

struct UniversalWalletIndexedTokenMetadata: Codable, Equatable {
    let ecosystem: String
    let chainId: String
    let assetId: String
    let decimals: Int
    let symbol: String?
    let name: String?
    let iconUrl: String?
    let metadataUrl: String?
    let isVerified: Bool
    let syncedAtMillis: Int64

    func validationErrors() -> Set<UniversalWalletIndexerValidationError> {
        var errors = Set<UniversalWalletIndexerValidationError>()

        if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
            errors.insert(.invalidEcosystem)
        }
        if !UniversalWalletIndexerContractValidator.matches(chainId, #"^[A-Za-z0-9._:-]{2,128}$"#) {
            errors.insert(.invalidChainId)
        }
        if !UniversalWalletIndexerContractValidator.isMachineText(assetId, maxLength: 160) {
            errors.insert(.invalidAssetId)
        }
        if !UniversalWalletIndexerContractValidator.decimalRange.contains(decimals) {
            errors.insert(.invalidDecimals)
        }
        if let symbol, !symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isHumanText(symbol, maxLength: 32) {
            errors.insert(.invalidSymbol)
        }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletIndexerContractValidator.isHumanText(name, maxLength: 96) {
            errors.insert(.invalidName)
        }
        if let iconUrl, !UniversalWalletIndexerContractValidator.isAssetUrl(iconUrl) {
            errors.insert(.invalidUrl)
        }
        if let metadataUrl, !UniversalWalletIndexerContractValidator.isAssetUrl(metadataUrl) {
            errors.insert(.invalidUrl)
        }
        if syncedAtMillis <= 0 {
            errors.insert(.invalidSyncedAt)
        }

        return errors
    }
}

struct UniversalWalletIndexerPageInfo: Codable, Equatable {
    let nextCursor: String?
    let limit: Int
    let total: Int?
    let syncedAtMillis: Int64

    func validationErrors() -> Set<UniversalWalletIndexerValidationError> {
        var errors = Set<UniversalWalletIndexerValidationError>()

        if let nextCursor, !UniversalWalletIndexerContractValidator.isMachineText(nextCursor, maxLength: 512) {
            errors.insert(.invalidCursor)
        }
        if !(1 ... UniversalWalletIndexerContractValidator.maxPageLimit).contains(limit) {
            errors.insert(.invalidLimit)
        }
        if let total, total < 0 {
            errors.insert(.invalidTotal)
        }
        if syncedAtMillis <= 0 {
            errors.insert(.invalidSyncedAt)
        }

        return errors
    }
}

enum UniversalWalletIndexedTransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
}

enum UniversalWalletIndexedTransactionDirection: String, Codable {
    case incoming
    case outgoing
    case `self`
    case unknown
}

enum UniversalWalletIndexedOperationType: String, Codable {
    case transfer
    case swap
    case stake
    case unstake
    case governance
    case offlineCash = "offline-cash"
    case sccp
    case contractCall = "contract-call"
    case mint
    case burn
    case fee
    case unknown
}

enum UniversalWalletIndexerValidationError: String, Error, CaseIterable {
    case invalidAccountId
    case invalidEcosystem
    case invalidChainId
    case invalidAssetId
    case invalidAmount
    case invalidDecimals
    case invalidSymbol
    case invalidName
    case invalidAddress
    case invalidTransactionId
    case invalidTimestamp
    case invalidBlockNumber
    case invalidCursor
    case invalidLimit
    case invalidTotal
    case invalidUrl
    case invalidSyncedAt
}

enum UniversalWalletIndexerContractValidator {
    static let decimalRange = 0 ... 255
    static let maxPageLimit = 250

    static func validateEnvelope(
        accountId: String,
        ecosystem: String,
        chainId: String,
        syncedAtMillis: Int64,
        errors: inout Set<UniversalWalletIndexerValidationError>
    ) {
        if !matches(accountId, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
            errors.insert(.invalidAccountId)
        }
        if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
            errors.insert(.invalidEcosystem)
        }
        if !matches(chainId, #"^[A-Za-z0-9._:-]{2,128}$"#) {
            errors.insert(.invalidChainId)
        }
        if syncedAtMillis <= 0 {
            errors.insert(.invalidSyncedAt)
        }
    }

    static func isUnsignedInteger(_ value: String) -> Bool {
        matches(value, #"^(0|[1-9][0-9]*)$"#)
    }

    static func isHttpsUrl(_ value: String) -> Bool {
        matches(value, #"^https://[^\s]+$"#)
    }

    static func isAssetUrl(_ value: String) -> Bool {
        matches(value, #"^(https|ipfs)://[^\s]+$"#)
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
