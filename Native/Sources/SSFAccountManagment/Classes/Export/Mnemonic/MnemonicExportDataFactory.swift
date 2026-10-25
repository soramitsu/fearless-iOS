import Foundation
import SoraKeystore
import SSFKeyPair
import SSFModels

// sourcery: AutoMockable
protocol MnemonicExportDataFactoryProtocol {
    func createMnemonicExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        cryptoType: CryptoType?,
        chain: ChainModel
    ) throws -> MnemonicExportData
}

struct MnemonicExportDataFactory: MnemonicExportDataFactoryProtocol {
    private let keystore: KeystoreProtocol
    private let mnemonicCreator: MnemonicCreator

    init(
        keystore: KeystoreProtocol,
        mnemonicCreator: MnemonicCreator
    ) {
        self.keystore = keystore
        self.mnemonicCreator = mnemonicCreator
    }

    func createMnemonicExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        cryptoType: CryptoType?,
        chain: ChainModel
    ) throws -> MnemonicExportData {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        let entropy = try keystore.fetchKey(for: entropyTag)

        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        let derivationPathTag = chain.derivationTag(metaId: metaId, accountId: accountId)
        let derivationPath: String? = try keystore.fetchDeriviationForAddress(derivationPathTag)

        return MnemonicExportData(
            mnemonic: mnemonic,
            derivationPath: derivationPath,
            cryptoType: cryptoType,
            chain: chain
        )
    }
}
