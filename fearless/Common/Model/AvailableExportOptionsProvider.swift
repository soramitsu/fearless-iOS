import SoraKeystore
protocol AvailableExportOptionsProviderProtocol {
    func getAvailableExportOptions(
        for metaId: String,
        accountId: AccountId?
    ) -> [ExportOption]
}

final class AvailableExportOptionsProvider {
    let keystore = Keychain()

    func getAvailableExportOptions(
        for metaId: String,
        accountId: AccountId?
    ) -> [ExportOption] {
        var options: [ExportOption] = [.keystore]
        if mnemonicAvailable(for: metaId, accountId: accountId) {
            options.append(.mnemonic)
        }
        if seedAvailable(for: metaId, accountId: accountId) {
            options.append(.seed)
        }
        return options
    }
}

private extension AvailableExportOptionsProvider {
    func mnemonicAvailable(for metaId: String, accountId: AccountId?) -> Bool {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        let entropy = try? keystore.fetchKey(for: entropyTag)
        return entropy != nil
    }

    func seedAvailable(for metaId: String, accountId: AccountId?) -> Bool {
        let ethereumTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(
            metaId,
            accountId: accountId
        )
        let ethereumSeed = try? keystore.fetchKey(for: ethereumTag)

        let substrateTag = KeystoreTagV2.substrateSeedTagForMetaId(
            metaId,
            accountId: accountId
        )
        let substrateSeed = try? keystore.fetchKey(for: substrateTag)
        return ethereumSeed != nil || substrateSeed != nil
    }
}
