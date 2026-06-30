import Foundation
import RobinHood
import SSFModels

enum UniversalWalletMigrationCutoff {
    static let defaultAtMillis: Int64 = 1_710_000_000_000
}

struct UniversalWalletMigrationSnapshot: Codable, Equatable {
    static let schemaVersionValue = 1

    let schemaVersion: Int
    let platform: UniversalWalletMigrationPlatform
    let hasUniversalWallet: Bool
    let legacyVaults: [UniversalWalletLegacyVaultDescriptor]
    let cutoffAtMillis: Int64
    let evaluatedAtMillis: Int64

    init(
        schemaVersion: Int = UniversalWalletMigrationSnapshot.schemaVersionValue,
        platform: UniversalWalletMigrationPlatform,
        hasUniversalWallet: Bool,
        legacyVaults: [UniversalWalletLegacyVaultDescriptor] = [],
        cutoffAtMillis: Int64,
        evaluatedAtMillis: Int64
    ) {
        self.schemaVersion = schemaVersion
        self.platform = platform
        self.hasUniversalWallet = hasUniversalWallet
        self.legacyVaults = legacyVaults
        self.cutoffAtMillis = cutoffAtMillis
        self.evaluatedAtMillis = evaluatedAtMillis
    }

    func requiredAction() -> UniversalWalletMigrationRequiredAction {
        if hasUniversalWallet {
            return .normalAccess
        }

        return legacyVaults.isEmpty ? .createUniversalWallet : .migrateBeforeAccess
    }

    func allowsNormalWalletAccess() -> Bool {
        requiredAction() == .normalAccess
    }

    func allowsLegacySecretExport() -> Bool {
        legacyVaults.contains { $0.canExportSecrets }
    }

    func validationErrors() -> Set<UniversalWalletMigrationValidationError> {
        var errors = Set<UniversalWalletMigrationValidationError>()

        if schemaVersion != Self.schemaVersionValue {
            errors.insert(.invalidSchemaVersion)
        }
        if cutoffAtMillis <= 0 || evaluatedAtMillis <= 0 {
            errors.insert(.invalidTimestamp)
        }

        var vaultIds = Set<String>()
        legacyVaults.forEach { vault in
            errors.formUnion(vault.validationErrors())
            if !vaultIds.insert(vault.vaultId).inserted {
                errors.insert(.duplicateVaultId)
            }
        }

        return errors
    }
}

struct UniversalWalletLegacyVaultDescriptor: Codable, Equatable {
    let vaultId: String
    let accountId: String
    let ecosystem: String
    let address: String
    let displayName: String?
    let mode: UniversalWalletLegacyVaultMode
    let exportOnlyReason: String
    let canExportSecrets: Bool
    let canSignTransactions: Bool
    let discoveredAtMillis: Int64
    let lastExportedAtMillis: Int64?

    init(
        vaultId: String,
        accountId: String,
        ecosystem: String,
        address: String,
        displayName: String? = nil,
        mode: UniversalWalletLegacyVaultMode = .exportOnly,
        exportOnlyReason: String,
        canExportSecrets: Bool = true,
        canSignTransactions: Bool = false,
        discoveredAtMillis: Int64,
        lastExportedAtMillis: Int64? = nil
    ) {
        self.vaultId = vaultId
        self.accountId = accountId
        self.ecosystem = ecosystem
        self.address = address
        self.displayName = displayName
        self.mode = mode
        self.exportOnlyReason = exportOnlyReason
        self.canExportSecrets = canExportSecrets
        self.canSignTransactions = canSignTransactions
        self.discoveredAtMillis = discoveredAtMillis
        self.lastExportedAtMillis = lastExportedAtMillis
    }

    init(
        vaultId: String,
        accountId: String,
        ecosystem: UniversalWalletEcosystem,
        address: String,
        displayName: String? = nil,
        mode: UniversalWalletLegacyVaultMode = .exportOnly,
        exportOnlyReason: String,
        canExportSecrets: Bool = true,
        canSignTransactions: Bool = false,
        discoveredAtMillis: Int64,
        lastExportedAtMillis: Int64? = nil
    ) {
        self.init(
            vaultId: vaultId,
            accountId: accountId,
            ecosystem: ecosystem.rawValue,
            address: address,
            displayName: displayName,
            mode: mode,
            exportOnlyReason: exportOnlyReason,
            canExportSecrets: canExportSecrets,
            canSignTransactions: canSignTransactions,
            discoveredAtMillis: discoveredAtMillis,
            lastExportedAtMillis: lastExportedAtMillis
        )
    }

    func validationErrors() -> Set<UniversalWalletMigrationValidationError> {
        var errors = Set<UniversalWalletMigrationValidationError>()

        if !UniversalWalletMigrationContractValidator.matches(vaultId, #"^legacy_[A-Za-z0-9_-]{8,64}$"#) {
            errors.insert(.invalidVaultId)
        }
        if !UniversalWalletMigrationContractValidator.matches(accountId, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
            errors.insert(.invalidAccountId)
        }
        if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
            errors.insert(.invalidEcosystem)
        }
        if !UniversalWalletMigrationContractValidator.isMachineText(address, maxLength: 256) {
            errors.insert(.invalidAddress)
        }
        if let displayName, !UniversalWalletMigrationContractValidator.isHumanText(displayName, maxLength: 64) {
            errors.insert(.invalidDisplayName)
        }
        if mode != .exportOnly {
            errors.insert(.invalidLegacyMode)
        }
        if !UniversalWalletMigrationContractValidator.isHumanText(exportOnlyReason, maxLength: 160) {
            errors.insert(.invalidExportReason)
        }
        if !canExportSecrets {
            errors.insert(.exportDisabled)
        }
        if canSignTransactions {
            errors.insert(.legacySigningEnabled)
        }
        if discoveredAtMillis <= 0 || lastExportedAtMillis.map({ $0 < discoveredAtMillis }) == true {
            errors.insert(.invalidTimestamp)
        }

        return errors
    }
}

enum UniversalWalletMigrationPlatform: String, Codable {
    case android
    case ios
    case web
}

enum UniversalWalletMigrationRequiredAction: String, Codable {
    case normalAccess = "normal-access"
    case createUniversalWallet = "create-universal-wallet"
    case migrateBeforeAccess = "migrate-before-access"
}

enum UniversalWalletLegacyVaultMode: String, Codable {
    case exportOnly = "export-only"
}

enum UniversalWalletMigrationValidationError: String, Error, CaseIterable {
    case invalidSchemaVersion
    case invalidVaultId
    case duplicateVaultId
    case invalidAccountId
    case invalidEcosystem
    case invalidAddress
    case invalidDisplayName
    case invalidLegacyMode
    case invalidExportReason
    case exportDisabled
    case legacySigningEnabled
    case invalidTimestamp
}

enum UniversalWalletMigrationContractValidator {
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

struct IOSUniversalWalletMigrationSnapshotBuilder {
    let cutoffAtMillis: Int64
    let clockMillis: () -> Int64

    init(
        cutoffAtMillis: Int64,
        clockMillis: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1000)
        }
    ) {
        self.cutoffAtMillis = cutoffAtMillis
        self.clockMillis = clockMillis
    }

    func build(accounts: [MetaAccountModel]) -> UniversalWalletMigrationSnapshot {
        UniversalWalletMigrationSnapshot(
            platform: .ios,
            hasUniversalWallet: accounts.contains { $0.hasCompleteUniversalWallet },
            legacyVaults: accounts.flatMap { account in
                account.hasCompleteUniversalWallet ? [] : account.legacyVaultDescriptors(cutoffAtMillis: cutoffAtMillis)
            },
            cutoffAtMillis: cutoffAtMillis,
            evaluatedAtMillis: max(clockMillis(), cutoffAtMillis)
        )
    }
}

protocol UniversalWalletMigrationSnapshotProviding {
    func fetchSnapshot(completion: @escaping (Result<UniversalWalletMigrationSnapshot, Error>) -> Void)
}

final class IOSUniversalWalletMigrationSnapshotProvider: UniversalWalletMigrationSnapshotProviding {
    typealias FetchAccountsClosure = (@escaping (Result<[MetaAccountModel], Error>) -> Void) -> Void

    private let builder: IOSUniversalWalletMigrationSnapshotBuilder
    private let fetchAccounts: FetchAccountsClosure

    init(
        builder: IOSUniversalWalletMigrationSnapshotBuilder = IOSUniversalWalletMigrationSnapshotBuilder(
            cutoffAtMillis: UniversalWalletMigrationCutoff.defaultAtMillis
        ),
        fetchAccounts: @escaping FetchAccountsClosure
    ) {
        self.builder = builder
        self.fetchAccounts = fetchAccounts
    }

    convenience init(
        repository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        builder: IOSUniversalWalletMigrationSnapshotBuilder = IOSUniversalWalletMigrationSnapshotBuilder(
            cutoffAtMillis: UniversalWalletMigrationCutoff.defaultAtMillis
        )
    ) {
        self.init(builder: builder) { completion in
            let operation = repository.fetchAllOperation(
                with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true)
            )
            operation.completionBlock = {
                DispatchQueue.main.async {
                    if let result = operation.result {
                        completion(result)
                    } else {
                        completion(.failure(BaseOperationError.parentOperationCancelled))
                    }
                }
            }

            operationManager.enqueue(operations: [operation], in: .transient)
        }
    }

    func fetchSnapshot(completion: @escaping (Result<UniversalWalletMigrationSnapshot, Error>) -> Void) {
        fetchAccounts { [builder] result in
            completion(result.map { builder.build(accounts: $0) })
        }
    }
}

struct IOSUniversalWalletLegacyExportTarget: Equatable {
    let wallet: MetaAccountModel
    let chainId: ChainModel.Id
    let accountId: AccountId?
    let isEthereumBased: Bool
    let address: String
    let ecosystem: UniversalWalletEcosystem
    let descriptor: UniversalWalletLegacyVaultDescriptor
}

enum IOSUniversalWalletLegacyExportResolver {
    static func resolve(
        descriptor: UniversalWalletLegacyVaultDescriptor,
        accounts: [MetaAccountModel]
    ) -> IOSUniversalWalletLegacyExportTarget? {
        guard descriptor.canExportSecrets,
              !descriptor.canSignTransactions,
              descriptor.mode == .exportOnly,
              descriptor.validationErrors().isEmpty,
              let ecosystem = UniversalWalletEcosystem(rawValue: descriptor.ecosystem),
              let chainId = legacyExportChainId(for: ecosystem) else {
            return nil
        }

        guard let wallet = accounts.first(where: {
            $0.matchesLegacyVaultDescriptor(descriptor, ecosystem: ecosystem) &&
                $0.hasLegacyRootMaterial(for: ecosystem)
        }) else {
            return nil
        }

        return IOSUniversalWalletLegacyExportTarget(
            wallet: wallet,
            chainId: chainId,
            accountId: nil,
            isEthereumBased: ecosystem == .evm,
            address: descriptor.address,
            ecosystem: ecosystem,
            descriptor: descriptor
        )
    }

    private static func legacyExportChainId(for ecosystem: UniversalWalletEcosystem) -> ChainModel.Id? {
        switch ecosystem {
        case .substrate:
            return Chain.polkadot.genesisHash
        case .evm:
            return Chain.moonriver.genesisHash
        case .ton, .bitcoin, .solana, .iroha:
            return nil
        }
    }
}

private extension MetaAccountModel {
    var hasCompleteUniversalWallet: Bool {
        substrateAddress != nil &&
            evmAddress != nil &&
            tonAddress != nil &&
            bitcoinAddress != nil &&
            solanaAddress != nil &&
            irohaAddress != nil
    }

    func legacyVaultDescriptors(cutoffAtMillis: Int64) -> [UniversalWalletLegacyVaultDescriptor] {
        var descriptors = [
            legacyVault(
                ecosystem: .substrate,
                address: substrateAddress ?? unavailableAddress(for: .substrate),
                cutoffAtMillis: cutoffAtMillis
            )
        ]

        if ethereumAddress != nil || ethereumPublicKey != nil {
            descriptors.append(
                legacyVault(
                    ecosystem: .evm,
                    address: evmAddress ?? unavailableAddress(for: .evm),
                    cutoffAtMillis: cutoffAtMillis
                )
            )
        }

        return descriptors
    }

    func legacyVault(
        ecosystem: UniversalWalletEcosystem,
        address: String,
        cutoffAtMillis: Int64
    ) -> UniversalWalletLegacyVaultDescriptor {
        UniversalWalletLegacyVaultDescriptor(
            vaultId: "legacy_ios_\(migrationSafeId)_\(ecosystem.rawValue)",
            accountId: "ios-\(migrationSafeId)-\(ecosystem.rawValue)",
            ecosystem: ecosystem,
            address: address,
            displayName: name.safeMigrationDisplayName,
            exportOnlyReason: "pre-cutoff account export",
            canExportSecrets: true,
            canSignTransactions: false,
            discoveredAtMillis: cutoffAtMillis
        )
    }

    func matchesLegacyVaultDescriptor(
        _ descriptor: UniversalWalletLegacyVaultDescriptor,
        ecosystem: UniversalWalletEcosystem
    ) -> Bool {
        descriptor.vaultId == "legacy_ios_\(migrationSafeId)_\(ecosystem.rawValue)" &&
            descriptor.accountId == "ios-\(migrationSafeId)-\(ecosystem.rawValue)" &&
            descriptor.address == legacyVaultAddress(for: ecosystem)
    }

    func hasLegacyRootMaterial(for ecosystem: UniversalWalletEcosystem) -> Bool {
        switch ecosystem {
        case .substrate:
            return !substrateAccountId.isEmpty && !substratePublicKey.isEmpty
        case .evm:
            return ethereumAddress != nil || ethereumPublicKey != nil
        case .ton, .bitcoin, .solana, .iroha:
            return false
        }
    }

    func legacyVaultAddress(for ecosystem: UniversalWalletEcosystem) -> String {
        switch ecosystem {
        case .substrate:
            return substrateAddress ?? unavailableAddress(for: .substrate)
        case .evm:
            return evmAddress ?? unavailableAddress(for: .evm)
        case .ton, .bitcoin, .solana, .iroha:
            return unavailableAddress(for: ecosystem)
        }
    }

    var substrateAddress: String? {
        guard substrateAccountId.count == 32 else {
            return nil
        }

        return try? substrateAccountId.toAddress(using: .substrate(0))
    }

    var evmAddress: String? {
        guard let ethereumAddress, ethereumAddress.count == 20 else {
            return nil
        }

        return try? ethereumAddress.toAddress(using: .ethereum)
    }

    var tonAddress: String? {
        guard let account = chainAccount(matching: Self.tonChainIds) else {
            return nil
        }

        return try? TonAddressCodec.v4R2Addresses(publicKey: account.publicKey).nonBounceable
    }

    var bitcoinAddress: String? {
        chainAccount(matching: Self.bitcoinMainnetChainIds).flatMap {
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.bitcoinMainnet.chainId,
                publicKey: $0.publicKey
            )
        } ?? chainAccount(matching: Self.bitcoinTestnetChainIds).flatMap {
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.bitcoinTestnet.chainId,
                publicKey: $0.publicKey
            )
        }
    }

    var solanaAddress: String? {
        chainAccount(matching: Self.solanaChainIds).flatMap {
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.solanaMainnet.chainId,
                publicKey: $0.publicKey
            )
        }
    }

    var irohaAddress: String? {
        chainAccount(matching: Self.tairaChainIds).flatMap {
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.taira.chainId,
                publicKey: $0.publicKey
            )
        } ?? chainAccount(matching: Self.nexusChainIds).flatMap {
            UniversalWalletChainAccountSupport.address(
                for: UniversalWalletRegistry.nexus.chainId,
                publicKey: $0.publicKey
            )
        }
    }

    func chainAccount(matching chainIds: Set<String>) -> ChainAccountModel? {
        chainAccounts.first { chainIds.contains($0.chainId.lowercased()) }
    }

    func unavailableAddress(for ecosystem: UniversalWalletEcosystem) -> String {
        "unavailable:ios:\(migrationSafeId):\(ecosystem.rawValue)"
    }

    var migrationSafeId: String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._:-")
        let normalized = metaId
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }

        let value = String(normalized).prefix(40)
        return value.isEmpty ? "account" : String(value)
    }

    static let tonChainIds: Set<String> = [
        "ton-mainnet",
        "ton:mainnet"
    ]

    static let bitcoinMainnetChainIds: Set<String> = [
        UniversalWalletRegistry.bitcoinMainnet.chainId,
        UniversalWalletRegistry.bitcoinMainnet.id
    ]

    static let bitcoinTestnetChainIds: Set<String> = [
        UniversalWalletRegistry.bitcoinTestnet.chainId,
        UniversalWalletRegistry.bitcoinTestnet.id
    ]

    static let solanaChainIds: Set<String> = [
        UniversalWalletRegistry.solanaMainnet.chainId,
        UniversalWalletRegistry.solanaMainnet.id,
        UniversalWalletRegistry.solanaDevnet.chainId,
        UniversalWalletRegistry.solanaDevnet.id
    ]

    static let tairaChainIds: Set<String> = [
        UniversalWalletRegistry.taira.chainId,
        UniversalWalletRegistry.taira.id
    ]

    static let nexusChainIds: Set<String> = [
        UniversalWalletRegistry.nexus.chainId,
        UniversalWalletRegistry.nexus.id
    ]
}

private extension String {
    var safeMigrationDisplayName: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { !CharacterSet.controlCharacters.contains($0) }
            .map(Character.init)
            .prefix(64)

        let sanitized = String(value)
        return sanitized.isEmpty ? nil : sanitized
    }
}
