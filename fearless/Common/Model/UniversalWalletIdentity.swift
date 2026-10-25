import Foundation

struct UniversalWalletIdentity: Codable, Equatable {
    static let schemaVersionValue = 2

    let schemaVersion: Int
    let walletId: String
    let displayName: String
    let source: Source
    let status: Status
    let publicAccounts: [PublicAccount]
    let createdAtMillis: Int64
    let updatedAtMillis: Int64?
    let legacyExportOnlyReason: String?

    init(
        schemaVersion: Int = UniversalWalletIdentity.schemaVersionValue,
        walletId: String,
        displayName: String,
        source: Source,
        status: Status,
        publicAccounts: [PublicAccount],
        createdAtMillis: Int64,
        updatedAtMillis: Int64? = nil,
        legacyExportOnlyReason: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.walletId = walletId
        self.displayName = displayName
        self.source = source
        self.status = status
        self.publicAccounts = publicAccounts
        self.createdAtMillis = createdAtMillis
        self.updatedAtMillis = updatedAtMillis
        self.legacyExportOnlyReason = legacyExportOnlyReason
    }

    func validationErrors() -> Set<ValidationError> {
        var errors = Set<ValidationError>()

        if schemaVersion != Self.schemaVersionValue {
            errors.insert(.invalidSchemaVersion)
        }
        if !Self.matches(walletId, #"^uw2_[A-Za-z0-9_-]{16,64}$"#) {
            errors.insert(.invalidWalletId)
        }
        if !Self.isHumanText(displayName, maxLength: 64) {
            errors.insert(.invalidDisplayName)
        }
        if createdAtMillis <= 0 || updatedAtMillis.map({ $0 < createdAtMillis }) == true {
            errors.insert(.invalidTimestamps)
        }

        if status != .legacyExportOnly, publicAccounts.isEmpty {
            errors.insert(.publicAccountsRequired)
        }
        if status == .active {
            let ecosystems = Set(publicAccounts.compactMap { UniversalWalletEcosystem(rawValue: $0.ecosystem) })
            if ecosystems != Set(UniversalWalletEcosystem.allCases) {
                errors.insert(.missingActiveEcosystem)
            }
        }
        if status == .legacyExportOnly {
            if source != .legacyImport {
                errors.insert(.invalidLegacySource)
            }
            if !Self.isHumanText(legacyExportOnlyReason, maxLength: 160) {
                errors.insert(.legacyReasonRequired)
            }
        } else if legacyExportOnlyReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            errors.insert(.legacyReasonNotAllowed)
        }

        var accountIds = Set<String>()
        publicAccounts.forEach { account in
            errors.formUnion(account.validationErrors())
            if !accountIds.insert(account.accountId).inserted {
                errors.insert(.duplicateAccountId)
            }
        }

        return errors
    }

    func requireValid() throws -> UniversalWalletIdentity {
        let errors = validationErrors()
        if !errors.isEmpty {
            throw UniversalWalletIdentityError(errors: errors)
        }

        return self
    }

    struct PublicAccount: Codable, Equatable {
        let accountId: String
        let ecosystem: String
        let address: String
        let chainId: String?
        let derivationPath: String?
        let publicKeyHex: String?
        let isDefault: Bool

        init(
            accountId: String,
            ecosystem: String,
            address: String,
            chainId: String? = nil,
            derivationPath: String? = nil,
            publicKeyHex: String? = nil,
            isDefault: Bool = true
        ) {
            self.accountId = accountId
            self.ecosystem = ecosystem
            self.address = address
            self.chainId = chainId
            self.derivationPath = derivationPath
            self.publicKeyHex = publicKeyHex
            self.isDefault = isDefault
        }

        init(
            accountId: String,
            ecosystem: UniversalWalletEcosystem,
            address: String,
            chainId: String? = nil,
            derivationPath: String? = nil,
            publicKeyHex: String? = nil,
            isDefault: Bool = true
        ) {
            self.init(
                accountId: accountId,
                ecosystem: ecosystem.rawValue,
                address: address,
                chainId: chainId,
                derivationPath: derivationPath,
                publicKeyHex: publicKeyHex,
                isDefault: isDefault
            )
        }

        func validationErrors() -> Set<ValidationError> {
            var errors = Set<ValidationError>()

            if !UniversalWalletIdentity.matches(accountId, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
                errors.insert(.invalidAccountId)
            }
            if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
                errors.insert(.invalidEcosystem)
            }
            if !UniversalWalletIdentity.isMachineText(address, maxLength: 256) {
                errors.insert(.invalidAddress)
            }
            if let chainId, !UniversalWalletIdentity.matches(chainId, #"^[A-Za-z0-9._:-]{2,128}$"#) {
                errors.insert(.invalidChainId)
            }
            if let derivationPath,
               !derivationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !UniversalWalletIdentity.matches(derivationPath, #"^m(?:/[0-9]+'?)*$"#) {
                errors.insert(.invalidDerivationPath)
            }
            if let publicKeyHex,
               !UniversalWalletIdentity.matches(publicKeyHex, #"^[0-9a-f]{64,260}$"#) || publicKeyHex.count % 2 != 0 {
                errors.insert(.invalidPublicKeyHex)
            }

            return errors
        }
    }

    enum Source: String, Codable {
        case created24Word = "created-24-word"
        case imported12Word = "imported-12-word"
        case imported24Word = "imported-24-word"
        case legacyImport = "legacy-import"
    }

    enum Status: String, Codable {
        case active
        case migrationRequired = "migration-required"
        case legacyExportOnly = "legacy-export-only"
    }

    enum ValidationError: String, Error, CaseIterable {
        case invalidSchemaVersion
        case invalidWalletId
        case invalidDisplayName
        case invalidTimestamps
        case publicAccountsRequired
        case missingActiveEcosystem
        case invalidLegacySource
        case legacyReasonRequired
        case legacyReasonNotAllowed
        case duplicateAccountId
        case invalidAccountId
        case invalidEcosystem
        case invalidAddress
        case invalidChainId
        case invalidDerivationPath
        case invalidPublicKeyHex
    }

    struct UniversalWalletIdentityError: Error, Equatable {
        let errors: Set<ValidationError>
    }

    private static func isHumanText(_ value: String?, maxLength: Int) -> Bool {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        return !normalized.isEmpty &&
            normalized.count <= maxLength &&
            normalized.rangeOfCharacter(from: .controlCharacters) == nil
    }

    private static func isMachineText(_ value: String, maxLength: Int) -> Bool {
        value == value.trimmingCharacters(in: .whitespacesAndNewlines) &&
            !value.isEmpty &&
            value.count <= maxLength &&
            value.unicodeScalars.allSatisfy { $0.value > 0x20 && $0.value != 0x7F }
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
