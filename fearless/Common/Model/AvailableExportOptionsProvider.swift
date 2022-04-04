import SoraKeystore
protocol AvailableExportOptionsProviderProtocol {
    func getAvailableExportOptions(
        for account: MetaAccountModel,
        accountId: AccountId?,
        isEthereum: Bool
    ) -> [ExportOption]
}

final class AvailableExportOptionsProvider: AvailableExportOptionsProviderProtocol {
    let keystore = Keychain()

    func getAvailableExportOptions(
        for account: MetaAccountModel,
        accountId: AccountId?,
        isEthereum: Bool
    ) -> [ExportOption] {
        var options: [ExportOption] = [.keystore]
        if mnemonicAvailable(for: account, accountId: accountId, isEthereum: isEthereum) {
            options.append(.mnemonic)
        }
        if seedAvailable(for: account, accountId: accountId) {
            options.append(.seed)
        }
        return options
    }
}

private extension AvailableExportOptionsProvider {
    func mnemonicAvailable(for account: MetaAccountModel, accountId: AccountId?, isEthereum: Bool) -> Bool {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(account.metaId, accountId: accountId)
        let entropy = try? keystore.fetchKey(for: entropyTag)
        if isEthereum {
            if !account.canExportEthereumMnemonic {
                return false
            }
            let derivationPathTag = KeystoreTagV2.ethereumDerivationTagForMetaId(account.metaId, accountId: accountId)
            let derivationPath = try? keystore.fetchKey(for: derivationPathTag)
            guard let path = derivationPath else {
                return false
            }
            let dpString = String(data: path, encoding: .utf8)
            return entropy != nil && dpString != nil
        }
        return entropy != nil
    }

    func seedAvailable(for metaId: String, accountId: AccountId?) -> Bool {
        let ethereumTag = KeystoreTagV2.ethereumSeedTagForMetaId(
            metaId,
            accountId: accountId
        )
        let ethereumSeed = try? keystore.fetchKey(for: ethereumTag)

        let substrateTag = KeystoreTagV2.substrateSeedTagForMetaId(
            account.metaId,
            accountId: accountId
        )
        let substrateSeed = try? keystore.fetchKey(for: substrateTag)
        return ethereumSeed != nil || substrateSeed != nil
    }
}
