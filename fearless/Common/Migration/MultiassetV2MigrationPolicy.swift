import Foundation
import CoreData
import IrohaCrypto

class MultiassetV2MigrationPolicy: NSEntityMigrationPolicy {
    override func end(_ mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        guard let keystoreMigrator = manager
            .userInfo?[UserStorageMigratorKeys.keystoreMigrator] as? KeystoreMigrating else {
            fatalError("No keystore migrator found in context")
        }

        let entityName = "CDMetaAccount"
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let context = manager.sourceContext
        let results = try context.fetch(request)

        for metaAccount in results {
            guard let address = metaAccount.value(forKey: "ethereumAddress") as? String,
                  let metaId = metaAccount.value(forKey: "metaId") as? String else {
                continue
            }

            if let ethereumPublicKey = try migrateKeystore(
                for: address,
                metaId: metaId,
                keystoreMigrator: keystoreMigrator
            ) {
                let rawPublicKey = ethereumPublicKey.rawData()
                metaAccount.setValue(rawPublicKey, forKey: "ethereumPublicKey")

                let ethereumAddress = try rawPublicKey.ethereumAddressFromPublicKey()
                metaAccount.setValue(ethereumAddress.toHex(), forKey: "ethereumAddress")
            }
        }
        try super.end(mapping, manager: manager)
    }

    private func migrateKeystore(
        for sourceAddress: AccountAddress,
        metaId: String,
        keystoreMigrator: KeystoreMigrating
    ) throws -> IRPublicKeyProtocol? {
        var publicKey: IRPublicKeyProtocol?
        
        let ethSecretKeyTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)
        let ethereumSeedTag = KeystoreTagV2.ethereumSeedTagForMetaId(metaId)

        let secretKey = try keystoreMigrator.fetchKey(for: ethSecretKeyTag)
        
        
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
