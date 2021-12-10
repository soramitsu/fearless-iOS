import Foundation
import CoreData
import FearlessUtils
import SoraKeystore
import IrohaCrypto

class SingleToMultiassetMigrationPolicy: NSEntityMigrationPolicy {
    var isSelected: Bool = false
    var order: Int32 = 0

    private lazy var addressFactory = SS58AddressFactory()

    override func createDestinationInstances(
        forSource accountItem: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: accountItem, in: mapping, manager: manager)

        guard let keystoreMigrator = manager
            .userInfo?[UserStorageMigratorKeys.keystoreMigrator] as? KeystoreMigrating else {
            fatalError("No keystore migrator found in context")
        }

        guard let metaAccount = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [accountItem]
        ).first else {
            fatalError("Meta account expected after mapping")
        }

        guard let sourceAddress = accountItem.value(forKey: "identifier") as? AccountAddress else {
            fatalError("Unexpected empty source address")
        }

        let metaId = UUID().uuidString
        metaAccount.setValue(metaId, forKey: "metaId")

        let accountId = try addressFactory.accountId(from: sourceAddress)

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

    // MARK: Private

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

            let ethereumDPString = DerivationPathConstants.defaultEthereum
            let secrets = try EthereumAccountImportWrapper().importEntropy(
                entropy,
                derivationPath: ethereumDPString
            )

            let ethSeedTag = KeystoreTagV2.ethereumSeedTagForMetaId(metaId)
            keystoreMigrator.save(key: secrets.seed, for: ethSeedTag)

            let ethSecretKeyTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)
            keystoreMigrator.save(key: secrets.keypair.privateKey().rawData(), for: ethSecretKeyTag)

            if let ethereumDP = ethereumDPString.data(using: .utf8) {
                let ethDPTag = KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
                keystoreMigrator.save(key: ethereumDP, for: ethDPTag)
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

        let oldDPTag = KeystoreTag.deriviationTagForAddress(sourceAddress)
        if let derivationPath = keystoreMigrator.fetchKey(for: oldDPTag) {
            keystoreMigrator.deleteKey(for: oldDPTag)

            let newDPTag = KeystoreTagV2.substrateDerivationTagForMetaId(metaId)
            keystoreMigrator.save(key: derivationPath, for: newDPTag)
        }

        return publicKey
    }
}
