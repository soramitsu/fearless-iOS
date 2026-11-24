import Foundation
import IrohaCrypto
import WalletCore

extension EngineStore: WalletServicing {
    private static let vocabulary: [String] = {
        guard let url = Bundle.module.url(forResource: "english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }()

    nonisolated var mnemonicWordList: [String] {
        Self.vocabulary
    }

    func generateMnemonic(length: MnemonicLength) throws -> [String] {
        guard let strength = IRMnemonicStrength(rawValue: UInt(length.rawValue * 32 / 3))
        else { throw WalletError.invalidMnemonic }
        do {
            return try mnemonicGenerator(strength)
        } catch { throw WalletError.storage("Unable to generate recovery words.") }
    }

    func validateMnemonic(_ words: [String]) -> MnemonicValidation {
        guard MnemonicLength(rawValue: words.count) != nil else { return .invalidLength(count: words.count) }
        let unknown = words.indices.filter { !Self.vocabulary.contains(words[$0]) }
        guard unknown.isEmpty else { return .unknownWords(indices: unknown) }
        return (try? IRMnemonicCreator().mnemonic(fromList: words.joined(separator: " "))) == nil ? .invalidChecksum :
            .valid
    }

    func wallets() throws -> [Wallet] {
        if let verifiedWallets {
            return verifiedWallets
        }
        guard state() == .uninitialized else { throw WalletError.vaultLocked }
        let records = try files.read([Wallet].self, "wallets.json") ?? []
        guard records.allSatisfy(\.isWatchOnly) else {
            throw WalletError.storage("Signing wallets require an authenticated vault.")
        }
        return records
    }

    func previewAddresses(for source: WalletImportSource) throws -> WalletAddressPreview {
        let accounts = try WalletKeys.importSource(source).accounts
        return try WalletAddressPreview(
            substrate: accounts.first(where: { $0.ecosystem == .substrate })
                .map { try WalletKeys.address($0, prefix: 0) },
            evm: accounts.first(where: { $0.ecosystem == .evm }).map { try WalletKeys.address($0, prefix: nil) }
        )
    }

    func addWallet(name: String, source: WalletImportSource) throws -> Wallet {
        if case .watchOnly = source {} else if key == nil {
            throw WalletError.vaultLocked
        }
        let material = try WalletKeys.importSource(source)
        var records = try wallets()
        for account in material.accounts {
            let address = try WalletKeys.address(account, prefix: 0)
            if let existing = try records.first(where: { wallet in
                try wallet.account(for: account.ecosystem)
                    .map { try WalletKeys.address($0, prefix: 0) == address } ?? false
            }) {
                throw WalletError.duplicateWallet(existing: existing.id)
            }
        }
        // A phrase generated on this Mac waits for the backup check; any other
        // source already exists outside the app.
        let wallet = Wallet(
            name: name,
            origin: material.origin,
            accounts: material.accounts,
            createdAt: Date(),
            isBackedUp: material.origin != .created
        )
        records.append(wallet)
        if let secret = material.secret {
            try commit(records, updating: wallet.id, secret: secret)
        } else {
            try saveMetadata(records)
        }
        return wallet
    }

    private func saveMetadata(_ records: [Wallet]) throws {
        if let key {
            try commit(records, document: document(), using: key)
        } else {
            guard state() == .uninitialized, records.allSatisfy(\.isWatchOnly) else { throw WalletError.vaultLocked }
            try files.write(records, "wallets.json")
        }
    }

    private func commit(_ records: [Wallet], updating id: WalletID, secret: WalletSecret?) throws {
        guard let key else { throw WalletError.vaultLocked }
        var doc = try document()
        var entries = try secrets(doc, using: key)
        entries[id.description] = secret
        doc.secrets = try seal(JSONEncoder().encode(entries), key: key, domain: "Fearless.wallets.v2")
        try commit(records, document: doc, using: key)
    }

    func wallet(_ id: WalletID) throws -> Wallet {
        guard let wallet = try wallets().first(where: { $0.id == id }) else { throw WalletError.walletNotFound }
        return wallet
    }

    func deleteWallet(_ id: WalletID) throws {
        let wallet = try wallet(id)
        let remaining = try wallets().filter { $0.id != id }
        if wallet.isWatchOnly {
            try saveMetadata(remaining)
        } else {
            try commit(remaining, updating: id, secret: nil)
        }
    }

    private func edit(_ id: WalletID, change: (inout Wallet) -> Void) throws {
        var all = try wallets()
        guard let index = all.firstIndex(where: { $0.id == id }) else { throw WalletError.walletNotFound }
        change(&all[index])
        try saveMetadata(all)
    }

    func renameWallet(_ id: WalletID, to name: String) throws {
        try edit(id) { $0.name = name }
    }

    func markBackedUp(_ id: WalletID) throws {
        try edit(id) { $0.isBackedUp = true }
    }

    private func approvedSecret(_ id: WalletID, _ approval: UserApproval) async throws -> WalletSecret {
        guard key != nil else { throw WalletError.vaultLocked }
        let record = try wallet(id)
        guard !record.isWatchOnly else { throw WalletError.watchOnly }
        let epoch = generation
        try await verify(approval)
        guard epoch == generation, let key else { throw WalletError.vaultLocked }
        guard let secret = try secrets(document(), using: key)[id.description]
        else { throw WalletError.storage("Wallet key is missing.") }
        guard try secret.accounts() == record.accounts
        else { throw WalletError.storage("Wallet account metadata failed verification.") }
        return secret
    }

    func exportMnemonic(_ id: WalletID, approval: UserApproval) async throws -> MnemonicBackup {
        try await approvedSecret(id, approval).mnemonicBackup()
    }

    func exportJSON(
        _ id: WalletID,
        ecosystem: Ecosystem,
        approval: UserApproval,
        exportPassword: String
    ) async throws -> Data {
        try await approvedSecret(id, approval).exportJSON(
            ecosystem: ecosystem,
            name: wallet(id).name,
            password: exportPassword
        )
    }

    func sign(_ payload: Data, walletID: WalletID, ecosystem: Ecosystem, approval: UserApproval) async throws -> Data {
        try await approvedSecret(walletID, approval).sign(payload, ecosystem: ecosystem)
    }

    func address(of id: WalletID, on chainID: ChainID) throws -> String {
        let chain = try Catalog.chain(chainID)
        let record = try wallet(id)
        guard let account = record.account(for: chain.evmID == nil ? .substrate : .evm)
        else { throw WalletError.unsupportedChain }
        return try WalletKeys.address(account, prefix: chain.prefix)
    }
}
