import SoraKeystore
import SSFModels
protocol AvailableExportOptionsProviderProtocol {
    func getAvailableExportOptions(
        for account: MetaAccountModel,
        accountId: AccountId?,
        isEthereum: Bool
    ) -> [ExportOption]

    func getAvailableExportOptions(for wallet: MetaAccountModel, accountId: AccountId?) -> [ExportOption]
}

final class AvailableExportOptionsProvider: AvailableExportOptionsProviderProtocol {
    let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol = Keychain()) { self.keystore = keystore }

    func getAvailableExportOptions(
        for account: MetaAccountModel,
        accountId: AccountId?,
        isEthereum: Bool
    ) -> [ExportOption] {
        if let ton = account.legacyTonAccount, accountId == nil {
            return nativeTonExportOptions(ton: ton, metaId: account.metaId)
        }
        var options: [ExportOption] = []

        if mnemonicAvailable(for: account, accountId: accountId, isEthereum: isEthereum) {
            options.append(.mnemonic)
        }

        if seedAvailable(for: account, accountId: accountId) {
            options.append(.seed)
        }

        options.append(.keystore)

        return options
    }

    func getAvailableExportOptions(for wallet: MetaAccountModel, accountId: AccountId?) -> [ExportOption] {
        if let ton = wallet.legacyTonAccount, accountId == nil {
            return nativeTonExportOptions(ton: ton, metaId: wallet.metaId)
        }
        var options: [ExportOption] = []

        if mnemonicAvailable(for: wallet, accountId: accountId, isEthereum: true),
           mnemonicAvailable(for: wallet, accountId: accountId, isEthereum: false) {
            options.append(.mnemonic)
        }
        if seedAvailable(for: wallet, accountId: accountId) {
            options.append(.seed)
        }

        options.append(.keystore)

        return options
    }
}

private extension AvailableExportOptionsProvider {
    /// Whether the item exists and, when it can be read without a sheet, passes `isValid`. An item
    /// moved to protected storage needs the device owner to read: listing the options never asks,
    /// so its presence is enough here; the export itself reads and verifies it.
    func isAvailable(_ tag: String, isValid: (Data) -> Bool = { _ in true }) -> Bool {
        do {
            let data = try WalletSecretAuthorization.withoutPrompt { try keystore.fetchKey(for: tag) }
            return isValid(data)
        } catch ProtectedKeychainError.interactionNotAllowed {
            return (try? keystore.checkKey(for: tag)) == true
        } catch {
            return false
        }
    }

    func nativeTonExportOptions(ton: LegacyTonAccount, metaId: String) -> [ExportOption] {
        guard isAvailable(KeystoreTagV2.entropyTagForMetaId(metaId), isValid: { (try? ton.mnemonic(from: $0)) != nil })
        else { return [] }
        return [.mnemonic]
    }

    func mnemonicAvailable(for account: MetaAccountModel, accountId: AccountId?, isEthereum: Bool) -> Bool {
        let entropyTag = KeystoreTagV2.entropyTagForMetaId(account.metaId, accountId: accountId)
        let entropy = isAvailable(entropyTag)
        if isEthereum {
            if !account.canExportEthereumMnemonic {
                return false
            }
            let derivationPathTag = KeystoreTagV2.ethereumDerivationTagForMetaId(account.metaId, accountId: accountId)
            return entropy && isAvailable(derivationPathTag, isValid: { String(data: $0, encoding: .utf8) != nil })
        }
        return entropy
    }

    func seedAvailable(for account: MetaAccountModel, accountId: AccountId?) -> Bool {
        let ethereumTag = KeystoreTagV2.ethereumSeedTagForMetaId(
            account.metaId,
            accountId: accountId
        )
        let substrateTag = KeystoreTagV2.substrateSeedTagForMetaId(
            account.metaId,
            accountId: accountId
        )
        if isAvailable(ethereumTag) || isAvailable(substrateTag) {
            return true
        }

        // The 4.0.x releases kept a per-chain account's seed only under the wallet-level tag.
        // Offer it for that account only if it recreates the account.
        guard
            let accountId,
            let chainAccount = account.chainAccounts.first(where: { $0.accountId == accountId }),
            !chainAccount.ethereumBased,
            let cryptoType = CryptoType(rawValue: chainAccount.cryptoType)
        else {
            return false
        }

        let export = try? WalletSecretAuthorization.withoutPrompt {
            try VerifiedSeedExportReader(keystore: keystore).fetchSeed(
                metaId: account.metaId,
                accountId: accountId,
                publicKey: chainAccount.publicKey,
                cryptoType: cryptoType,
                ethereumBased: false
            )
        }
        return export != nil
    }
}
