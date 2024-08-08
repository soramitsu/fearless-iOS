import SoraKeystore
import SSFModels

protocol AvailableExportOptionsProviderProtocol {
    func getAvailableExportOptions(
        for wallet: MetaAccountModel,
        accountId: AccountId?,
        ecosystem: Ecosystem
    ) -> [ExportOption]

    func getAvailableExportOptions(
        for wallet: MetaAccountModel,
        accountId: AccountId?
    ) -> [ExportOption]
}

final class AvailableExportOptionsProvider: AvailableExportOptionsProviderProtocol {
    let keystore = Keychain()

    func getAvailableExportOptions(
        for wallet: MetaAccountModel,
        accountId: AccountId?,
        ecosystem: Ecosystem
    ) -> [ExportOption] {
        var options: [ExportOption] = []

        switch ecosystem {
        case .substrate, .ethereumBased, .ethereum:
            if mnemonicAvailable(for: wallet, accountId: accountId, ecosystem: ecosystem) {
                options.append(.mnemonic)
            }

            if seedAvailable(for: wallet, accountId: accountId) {
                options.append(.seed)
            }

            options.append(.keystore)
        case .ton:
            options.append(.mnemonic)
        }

        return options
    }

    func getAvailableExportOptions(
        for wallet: MetaAccountModel,
        accountId: AccountId?
    ) -> [ExportOption] {
        let options = Ecosystem.allCases.map {
            getAvailableExportOptions(for: wallet, accountId: accountId, ecosystem: $0)
        }
        .reduce([], +)
        .uniq(predicate: { $0 })
        return options
    }
}

private extension AvailableExportOptionsProvider {
    func mnemonicAvailable(
        for wallet: MetaAccountModel,
        accountId: AccountId?,
        ecosystem: Ecosystem
    ) -> Bool {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: accountId)
        let entropy = try? keystore.fetchKey(for: entropyTag)

        switch ecosystem {
        case .substrate, .ton:
            return entropy != nil
        case .ethereumBased, .ethereum:
            if !wallet.canExportEthereumMnemonic {
                return false
            }
            let derivationPathTag = KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId, accountId: accountId)
            let derivationPath = try? keystore.fetchKey(for: derivationPathTag)
            guard let path = derivationPath else {
                return false
            }
            let dpString = String(data: path, encoding: .utf8)
            return entropy != nil && dpString != nil
        }
    }

    func seedAvailable(for wallet: MetaAccountModel, accountId: AccountId?) -> Bool {
        let ethereumTag = KeystoreTagV2.ethereumSeedTagForMetaId(
            wallet.metaId,
            accountId: accountId
        )
        let ethereumSeed = try? keystore.fetchKey(for: ethereumTag)

        let substrateTag = KeystoreTagV2.substrateSeedTagForMetaId(
            wallet.metaId,
            accountId: accountId
        )
        let substrateSeed = try? keystore.fetchKey(for: substrateTag)
        return ethereumSeed != nil || substrateSeed != nil
    }
}
