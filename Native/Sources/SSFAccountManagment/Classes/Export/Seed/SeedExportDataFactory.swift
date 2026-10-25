import Foundation
import SoraKeystore
import SSFModels

// sourcery: AutoMockable
protocol SeedExportDataFactoryProtocol {
    func createSeedExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        cryptoType: CryptoType,
        chain: ChainModel
    ) throws -> SeedExportData
}

struct SeedExportDataFactory: SeedExportDataFactoryProtocol {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func createSeedExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        cryptoType: CryptoType,
        chain: ChainModel
    ) throws -> SeedExportData {
        let seedTag = chain.seedTag(metaId: metaId, accountId: accountId)

        var optionalSeed: Data? = try keystore.fetchKey(for: seedTag)

        let keyTag = chain.keystoreTag(metaId: metaId, accountId: accountId)

        if optionalSeed == nil, cryptoType.supportsSeedFromSecretKey {
            optionalSeed = try keystore.fetchKey(for: keyTag)
        }

        guard let seed = optionalSeed else {
            throw SeedExportServiceError.missingSeed
        }

        //  We shouldn't show derivation path for ethereum seed. So just provide nil to hide it
        var derivationPath: String?
        if chain.isEthereumBased {
            let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(
                metaId,
                accountId: accountId
            )
            derivationPath = try keystore.fetchDeriviationForAddress(derivationTag)
        }

        return SeedExportData(
            seed: seed,
            derivationPath: derivationPath,
            chain: chain,
            cryptoType: cryptoType
        )
    }
}
