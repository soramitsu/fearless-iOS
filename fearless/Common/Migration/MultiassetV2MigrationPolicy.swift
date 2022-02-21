import Foundation
import CoreData
import IrohaCrypto

class MultiassetV2MigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource oldMetaAccount: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        guard let keystoreMigrator = manager
            .userInfo?[UserStorageMigratorKeys.keystoreMigrator] as? KeystoreMigrating else {
            fatalError("No keystore migrator found in context")
        }

        try super.createDestinationInstances(forSource: oldMetaAccount, in: mapping, manager: manager)

        guard let metaAccount = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [oldMetaAccount]
        ).first else {
            return
        }

        guard let address = metaAccount.value(forKey: "ethereumAddress") as? String,
              let metaId = metaAccount.value(forKey: "metaId") as? String else {
            return
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

    private func migrateKeystore(
        for _: AccountAddress,
        metaId: String,
        keystoreMigrator: KeystoreMigrating
    ) throws -> IRPublicKeyProtocol? {
        var publicKey: IRPublicKeyProtocol?

        let entropyTag = KeystoreTagV2.entropyTagForMetaId(metaId)

        if let entropy = keystoreMigrator.fetchKey(for: entropyTag) {
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

        return publicKey
    }
}
