import Foundation
import CoreData
import SSFUtils
import FearlessSecureStorage
import IrohaCrypto

final class SingleToMultiassetMigrationPolicy: NSEntityMigrationPolicy {
    private var isSelected = false
    private var order: Int32 = 0
    private var privateKeysUsed: [Data] = []

    private lazy var addressFactory = SS58AddressFactory()

    override func createDestinationInstances(
        forSource accountItem: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard let keystoreMigrator = manager
            .userInfo?[UserStorageMigratorKeys.keystoreMigrator] as? KeystoreMigrating else {
            fatalError("No keystore migrator found in context")
        }

        guard let sourceAddress = accountItem.value(forKey: "identifier") as? AccountAddress else {
            fatalError("Unexpected empty source address")
        }

        let accountId = try addressFactory.accountId(from: sourceAddress)

        if privateKeysUsed.contains(accountId) {
            return
        }

        try super.createDestinationInstances(forSource: accountItem, in: mapping, manager: manager)

        guard let metaAccount = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [accountItem]
        ).first else {
            return
        }

        privateKeysUsed.append(accountId)

        let metaId = UUID().uuidString
        metaAccount.setValue(metaId, forKey: "metaId")
        metaAccount.setValue(accountId.toHex(), forKey: "substrateAccountId")

        if !isSelected {
            isSelected = true
            metaAccount.setValue(true, forKey: "isSelected")
        } else {
            metaAccount.setValue(false, forKey: "isSelected")
        }

        metaAccount.setValue(order, forKey: "order")
        order += 1

        if let ethereumPublicKey = try migrateKeystore(
            for: sourceAddress,
            metaId: metaId,
            keystoreMigrator: keystoreMigrator
        ) {
            let rawPublicKey = ethereumPublicKey.rawData()
            metaAccount.setValue(rawPublicKey, forKey: "ethereumPublicKey")

            let ethereumAddress = try rawPublicKey.ethereumAddressFromPublicKey()
            metaAccount.setValue(ethereumAddress.toHex(), forKey: "ethereumAddress")
        }
    }

    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        guard let settingsMigrator = manager
            .userInfo?[UserStorageMigratorKeys.settingsMigrator] as? SettingsMigrating else {
            fatalError("No settings migrator found in context")
        }

        settingsMigrator.remove(key: SettingsKey.selectedAccount.rawValue)
        settingsMigrator.remove(key: SettingsKey.selectedConnection.rawValue)

        try super.end(mapping, manager: manager)
    }

    private func migrateKeystore(
        for sourceAddress: AccountAddress,
        metaId: String,
        keystoreMigrator: KeystoreMigrating
    ) throws -> IRPublicKeyProtocol? {
        var publicKey: IRPublicKeyProtocol?

        let oldEntropyTag = KeystoreTag.entropyTagForAddress(sourceAddress)
        if let entropy = keystoreMigrator.fetchKey(for: oldEntropyTag) {
            let newEntropyTag = KeystoreTagV2.entropyTagForMetaId(metaId)

            keystoreMigrator.deleteKey(for: oldEntropyTag)
            keystoreMigrator.save(key: entropy, for: newEntropyTag)

            let ethereumDerivationPath = DerivationPathConstants.defaultEthereum
            let secrets = try EthereumAccountImportWrapper().importEntropy(
                entropy,
                derivationPath: ethereumDerivationPath
            )

            let ethSeedTag = KeystoreTagV2.ethereumSeedTagForMetaId(metaId)
            keystoreMigrator.save(key: secrets.seed, for: ethSeedTag)

            let ethSecretKeyTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)
            keystoreMigrator.save(key: secrets.keypair.privateKey().rawData(), for: ethSecretKeyTag)

            if let ethereumDerivationPathData = ethereumDerivationPath.data(using: .utf8) {
                let ethDerivationPathTag = KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
                keystoreMigrator.save(key: ethereumDerivationPathData, for: ethDerivationPathTag)
            }

            publicKey = secrets.keypair.publicKey()
        }

        let oldSeedTag = KeystoreTag.seedTagForAddress(sourceAddress)
        if let seed = keystoreMigrator.fetchKey(for: oldSeedTag) {
            let newSeedTag = KeystoreTagV2.substrateSeedTagForMetaId(metaId)

            keystoreMigrator.deleteKey(for: oldSeedTag)
            keystoreMigrator.save(key: seed, for: newSeedTag)
        }

        let oldSecretKeyTag = KeystoreTag.secretKeyTagForAddress(sourceAddress)
        if let secretKey = keystoreMigrator.fetchKey(for: oldSecretKeyTag) {
            let newSecretKeyTag = KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)

            keystoreMigrator.deleteKey(for: oldSecretKeyTag)
            keystoreMigrator.save(key: secretKey, for: newSecretKeyTag)
        }

        let oldDerivationPathTag = KeystoreTag.deriviationTagForAddress(sourceAddress)
        if let derivationPath = keystoreMigrator.fetchKey(for: oldDerivationPathTag) {
            keystoreMigrator.deleteKey(for: oldDerivationPathTag)

            let newDerivationPathTag = KeystoreTagV2.substrateDerivationTagForMetaId(metaId)
            keystoreMigrator.save(key: derivationPath, for: newDerivationPathTag)
        }

        return publicKey
    }
}
