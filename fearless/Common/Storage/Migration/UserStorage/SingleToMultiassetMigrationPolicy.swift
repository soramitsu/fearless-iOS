import CoreData
import Foundation
import IrohaCrypto
import SoraKeystore
import SSFUtils

enum SingleToMultiassetMigrationError: LocalizedError {
    case keystoreMigratorMissing
    case settingsMigratorMissing
    case sourceAddressMissing
    case destinationAccountMissing

    var errorDescription: String? {
        switch self {
        case .keystoreMigratorMissing:
            return "The v1-to-v2 migration is missing its keystore migrator"
        case .settingsMigratorMissing:
            return "The v1-to-v2 migration is missing its settings migrator"
        case .sourceAddressMissing:
            return "The v1-to-v2 migration encountered an account without an address"
        case .destinationAccountMissing:
            return "The v1-to-v2 migration failed to create a destination account"
        }
    }
}

final class SingleToMultiassetMigrationPolicy: NSEntityMigrationPolicy {
    private struct LegacySecrets {
        let entropy: Data?
        let seed: Data?
        let secretKey: Data?
        let derivationPath: Data?

        var signingRank: Int {
            if secretKey != nil {
                return 3
            }

            if entropy != nil {
                return 2
            }

            if seed != nil {
                return 1
            }

            return 0
        }

        var materialCount: Int {
            [entropy, seed, secretKey, derivationPath]
                .compactMap { $0 }
                .count
        }
    }

    private struct SourceCandidate {
        let address: AccountAddress
        let name: Any?
        let publicKey: Any?
        let cryptoType: Any?
        let secrets: LegacySecrets

        func isPreferred(over candidate: SourceCandidate) -> Bool {
            if secrets.signingRank != candidate.secrets.signingRank {
                return secrets.signingRank > candidate.secrets.signingRank
            }

            if secrets.materialCount != candidate.secrets.materialCount {
                return secrets.materialCount > candidate.secrets.materialCount
            }

            return address < candidate.address
        }
    }

    private struct AccountMigration {
        let metaAccount: NSManagedObject
        let metaId: String
        var preferredCandidate: SourceCandidate
    }

    private var isSelected = false
    private var order: Int32 = 0
    private var migratedAccounts = [Data: AccountMigration]()

    private lazy var addressFactory = SS58AddressFactory()

    override func createDestinationInstances(
        forSource accountItem: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard
            let keystoreMigrator = manager
            .userInfo?[UserStorageMigratorKeys.keystoreMigrator] as? KeystoreMigrating
        else {
            throw SingleToMultiassetMigrationError.keystoreMigratorMissing
        }

        try keystoreMigrator.registerLegacyAccountRow()

        guard let sourceAddress = accountItem.value(forKey: "identifier") as? AccountAddress else {
            throw SingleToMultiassetMigrationError.sourceAddressMissing
        }

        let accountId = try addressFactory.accountId(from: sourceAddress)
        let secrets = try loadLegacySecrets(
            for: sourceAddress,
            keystoreMigrator: keystoreMigrator
        )
        let candidate = SourceCandidate(
            address: sourceAddress,
            name: accountItem.value(forKey: "username"),
            publicKey: accountItem.value(forKey: "publicKey"),
            cryptoType: accountItem.value(forKey: "cryptoType"),
            secrets: secrets
        )

        if var accountMigration = migratedAccounts[accountId] {
            if candidate.isPreferred(over: accountMigration.preferredCandidate) {
                applyMappedValues(
                    from: candidate,
                    to: accountMigration.metaAccount
                )
                accountMigration.preferredCandidate = candidate
                migratedAccounts[accountId] = accountMigration
            }

            try migrateKeystore(
                secrets,
                sourceAddress: sourceAddress,
                metaId: accountMigration.metaId,
                metaAccount: accountMigration.metaAccount,
                keystoreMigrator: keystoreMigrator
            )
            return
        }

        try super.createDestinationInstances(
            forSource: accountItem,
            in: mapping,
            manager: manager
        )

        guard
            let metaAccount = manager.destinationInstances(
                forEntityMappingName: mapping.name,
                sourceInstances: [accountItem]
            ).first
        else {
            throw SingleToMultiassetMigrationError.destinationAccountMissing
        }

        let metaId = UUID().uuidString
        metaAccount.setValue(metaId, forKey: "metaId")
        metaAccount.setValue(accountId.toHex(), forKey: "substrateAccountId")
        metaAccount.setValue(!isSelected, forKey: "isSelected")
        metaAccount.setValue(order, forKey: "order")

        migratedAccounts[accountId] = AccountMigration(
            metaAccount: metaAccount,
            metaId: metaId,
            preferredCandidate: candidate
        )

        isSelected = true
        order += 1

        try migrateKeystore(
            secrets,
            sourceAddress: sourceAddress,
            metaId: metaId,
            metaAccount: metaAccount,
            keystoreMigrator: keystoreMigrator
        )
    }

    override func end(
        _ mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard
            let settingsMigrator = manager
            .userInfo?[UserStorageMigratorKeys.settingsMigrator] as? SettingsMigrating
        else {
            throw SingleToMultiassetMigrationError.settingsMigratorMissing
        }

        settingsMigrator.remove(key: SettingsKey.selectedAccount.rawValue)
        settingsMigrator.remove(key: SettingsKey.selectedConnection.rawValue)

        try super.end(mapping, manager: manager)
    }

    private func loadLegacySecrets(
        for sourceAddress: AccountAddress,
        keystoreMigrator: KeystoreMigrating
    ) throws -> LegacySecrets {
        try LegacySecrets(
            entropy: keystoreMigrator.fetchKey(
                for: KeystoreTag.entropyTagForAddress(sourceAddress)
            ),
            seed: keystoreMigrator.fetchKey(
                for: KeystoreTag.seedTagForAddress(sourceAddress)
            ),
            secretKey: keystoreMigrator.fetchKey(
                for: KeystoreTag.secretKeyTagForAddress(sourceAddress)
            ),
            derivationPath: keystoreMigrator.fetchKey(
                for: KeystoreTag.deriviationTagForAddress(sourceAddress)
            )
        )
    }

    private func applyMappedValues(
        from candidate: SourceCandidate,
        to metaAccount: NSManagedObject
    ) {
        metaAccount.setValue(candidate.name, forKey: "name")
        metaAccount.setValue(candidate.publicKey, forKey: "substratePublicKey")
        metaAccount.setValue(candidate.cryptoType, forKey: "substrateCryptoType")
    }

    private func migrateKeystore(
        _ secrets: LegacySecrets,
        sourceAddress: AccountAddress,
        metaId: String,
        metaAccount: NSManagedObject,
        keystoreMigrator: KeystoreMigrating
    ) throws {
        let oldEntropyTag = KeystoreTag.entropyTagForAddress(sourceAddress)
        if let entropy = secrets.entropy {
            let newEntropyTag = KeystoreTagV2.entropyTagForMetaId(metaId)

            try stage(
                key: entropy,
                for: newEntropyTag,
                keystoreMigrator: keystoreMigrator
            )
            try scheduleDeletion(
                oldEntropyTag,
                keystoreMigrator: keystoreMigrator
            )

            let ethereumDerivationPath = DerivationPathConstants.defaultEthereum
            let secrets = try EthereumAccountImportWrapper().importEntropy(
                entropy,
                derivationPath: ethereumDerivationPath
            )

            try stage(
                key: secrets.seed,
                for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId),
                keystoreMigrator: keystoreMigrator
            )
            try stage(
                key: secrets.keypair.privateKey().rawData(),
                for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId),
                keystoreMigrator: keystoreMigrator
            )

            if let derivationPathData = ethereumDerivationPath.data(using: .utf8) {
                try stage(
                    key: derivationPathData,
                    for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId),
                    keystoreMigrator: keystoreMigrator
                )
            }

            let rawPublicKey = secrets.keypair.publicKey().rawData()
            metaAccount.setValue(rawPublicKey, forKey: "ethereumPublicKey")

            let ethereumAddress = try rawPublicKey.ethereumAddressFromPublicKey()
            metaAccount.setValue(ethereumAddress.toHex(), forKey: "ethereumAddress")
        }

        let oldSeedTag = KeystoreTag.seedTagForAddress(sourceAddress)
        if let seed = secrets.seed {
            try stage(
                key: seed,
                for: KeystoreTagV2.substrateSeedTagForMetaId(metaId),
                keystoreMigrator: keystoreMigrator
            )
            try scheduleDeletion(
                oldSeedTag,
                keystoreMigrator: keystoreMigrator
            )
        }

        let oldSecretKeyTag = KeystoreTag.secretKeyTagForAddress(sourceAddress)
        if let secretKey = secrets.secretKey {
            try stage(
                key: secretKey,
                for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId),
                keystoreMigrator: keystoreMigrator
            )
            try scheduleDeletion(
                oldSecretKeyTag,
                keystoreMigrator: keystoreMigrator
            )
        }

        let oldDerivationTag = KeystoreTag.deriviationTagForAddress(sourceAddress)
        if let derivationPath = secrets.derivationPath {
            try stage(
                key: derivationPath,
                for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId),
                keystoreMigrator: keystoreMigrator
            )
            try scheduleDeletion(
                oldDerivationTag,
                keystoreMigrator: keystoreMigrator
            )
        }
    }

    private func stage(
        key: Data,
        for identifier: String,
        keystoreMigrator: KeystoreMigrating
    ) throws {
        keystoreMigrator.save(key: key, for: identifier)
        try keystoreMigrator.throwIfResourceLimitExceeded()
    }

    private func scheduleDeletion(
        _ identifier: String,
        keystoreMigrator: KeystoreMigrating
    ) throws {
        keystoreMigrator.deleteKey(for: identifier)
        try keystoreMigrator.throwIfResourceLimitExceeded()
    }
}
