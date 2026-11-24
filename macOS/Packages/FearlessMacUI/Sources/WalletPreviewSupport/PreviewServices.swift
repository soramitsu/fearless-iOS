import CryptoKit
import Foundation
import WalletCore

struct PreviewVaultService: VaultServicing {
    let store: PreviewStore

    func state() async -> VaultState {
        await store.vaultState
    }

    func stateUpdates() -> AsyncStream<VaultState> {
        let id = UUID()
        let store = store
        return AsyncStream { continuation in
            let registration = Task { await store.addObserver(id, continuation) }
            continuation.onTermination = { _ in
                registration.cancel()
                Task { await store.removeObserver(id) }
            }
        }
    }

    func initialize(password: String) async throws {
        await store.pause()
        try await store.initialize(password: password)
    }

    func unlock(_ approval: UserApproval) async throws {
        await store.pause()
        try await store.unlock(approval)
    }

    func lock() async {
        await store.lock()
    }

    func changePassword(current: String, new: String) async throws {
        await store.pause()
        try await store.changePassword(current: current, new: new)
    }

    func biometricsAvailability() async -> BiometricsAvailability {
        await store.biometricsAvailability()
    }

    func setBiometricsEnabled(_ enabled: Bool, password: String) async throws {
        await store.pause()
        try await store.setBiometricsEnabled(enabled, password: password)
    }

    func verify(_ approval: UserApproval) async throws {
        await store.pause()
        try await store.check(approval)
    }

    func eraseAllData() async throws {
        await store.pause()
        await store.eraseAll()
    }
}

struct PreviewWalletService: WalletServicing {
    let store: PreviewStore

    var mnemonicWordList: [String] { PreviewBIP39.words }

    func wallets() async throws -> [Wallet] {
        await store.pause(scale: 0.5)
        return await store.wallets.map(\.wallet)
    }

    func generateMnemonic(length: MnemonicLength) async throws -> [String] {
        await store.pause(scale: 0.5)
        let words = PreviewBIP39.mnemonic(fromEntropy: PreviewBIP39.testEntropy(for: length))
        guard words.count == length.rawValue else { throw WalletError.unknown("The preview word list is missing.") }
        return words
    }

    func validateMnemonic(_ words: [String]) async -> MnemonicValidation {
        PreviewBIP39.validate(words)
    }

    func previewAddresses(for source: WalletImportSource) async throws -> WalletAddressPreview {
        await store.pause(scale: 0.5)
        let candidate = try Self.candidate(name: "Preview", source: source, now: Date())
        return WalletAddressPreview(
            substrate: candidate.address(on: PreviewCatalog.polkadot),
            evm: candidate.evmAddress
        )
    }

    func addWallet(name: String, source: WalletImportSource) async throws -> Wallet {
        await store.pause()
        if case .watchOnly = source {} else { try await store.requireUnlocked() }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = try Self.candidate(name: trimmed.isEmpty ? "Wallet" : trimmed, source: source, now: Date())
        return try await store.add(candidate)
    }

    func renameWallet(_ id: WalletID, to name: String) async throws {
        try await store.rename(id, to: name)
    }

    func deleteWallet(_ id: WalletID) async throws {
        await store.pause(scale: 0.5)
        try await store.delete(id)
    }

    func markBackedUp(_ id: WalletID) async throws {
        try await store.markBackedUp(id)
    }

    func exportMnemonic(_ id: WalletID, approval: UserApproval) async throws -> MnemonicBackup {
        await store.pause()
        try await store.requireUnlocked()
        try await store.check(approval)
        let wallet = try await store.stored(id)
        guard let phrase = wallet.phrase, wallet.wallet.hasRecoveryPhrase else { throw WalletError.watchOnly }
        return MnemonicBackup(words: phrase, options: wallet.options)
    }

    /// The hard/soft part of a Substrate path: everything before `///password`.
    static func publicDerivationPath(_ path: String) -> String? {
        let visible = path.components(separatedBy: "///").first ?? ""
        return visible.isEmpty ? nil : visible
    }

    func exportJSON(_ id: WalletID, ecosystem: Ecosystem, approval: UserApproval, exportPassword: String) async throws -> Data {
        await store.pause()
        try await store.requireUnlocked()
        try await store.check(approval)
        let wallet = try await store.stored(id)
        guard !wallet.wallet.isWatchOnly else { throw WalletError.watchOnly }
        let chain = ecosystem == .substrate ? PreviewCatalog.polkadot : PreviewCatalog.ethereum
        guard let address = wallet.address(on: chain) else { throw WalletError.unsupportedChain }
        let object: [String: Any] = [
            "address": address,
            "encoded": "PREVIEW-ONLY-NOT-A-REAL-KEYSTORE",
            "encoding": ["content": ["pkcs8", "sr25519"], "type": ["scrypt", "xsalsa20-poly1305"], "version": "3"],
            "meta": ["name": wallet.wallet.name, "preview": true]
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    func address(of id: WalletID, on chainID: ChainID) async throws -> String {
        await store.pause(scale: 0.5)
        let wallet = try await store.stored(id)
        guard let chain = PreviewCatalog.chain(chainID), let address = wallet.address(on: chain) else {
            throw WalletError.unsupportedChain
        }
        return address
    }

    /// Builds a made-up wallet for an import source. Nothing is derived from
    /// the input beyond a hash that makes the result stable.
    static func candidate(name: String, source: WalletImportSource, now: Date) throws -> StoredWallet {
        let phraseOrigin: WalletOrigin
        switch source {
        case .created: phraseOrigin = .created
        default: phraseOrigin = .mnemonic
        }
        switch source {
        case let .created(words, options), let .mnemonic(words, options):
            guard PreviewBIP39.validate(words) == .valid else { throw WalletError.invalidMnemonic }
            let normalized = words.map { $0.lowercased() }.joined(separator: " ")
            let seed = Data((normalized + "|" + options.substrateCryptoType.rawValue + "|" + options.substrateDerivationPath).utf8)
            let evmSeed = Data((normalized + "|" + options.evmDerivationPath).utf8)
            let account = Array(SHA256.hash(data: seed))
            let evm = PreviewAddressCodec.fakeEVMAddress(seed: evmSeed)
            return StoredWallet(
                wallet: Wallet(
                    name: name, origin: phraseOrigin,
                    accounts: [
                        WalletAccount(ecosystem: .substrate, cryptoType: options.substrateCryptoType, publicKey: Data(account), derivationPath: publicDerivationPath(options.substrateDerivationPath)),
                        WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: Data(PreviewBIP39.bytes(fromHex: String(evm.dropFirst(2)))), derivationPath: options.evmDerivationPath)
                    ],
                    // A phrase made on this Mac is not backed up yet; an imported one is.
                    createdAt: now, isBackedUp: phraseOrigin == .mnemonic
                ),
                substrateAccount: account, substrateAddresses: [:], evmAddress: evm, phrase: words.map { $0.lowercased() },
                options: options
            )
        case let .seed(hex, ecosystem, options):
            let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let digits = cleaned.hasPrefix("0x") ? String(cleaned.dropFirst(2)) : cleaned
            guard digits.count == 64, digits.allSatisfy(\.isHexDigit) else { throw WalletError.invalidSeed }
            let seed = Data((digits + "|" + options.substrateCryptoType.rawValue).utf8)
            switch ecosystem {
            case .substrate:
                let account = Array(SHA256.hash(data: seed))
                return StoredWallet(
                    wallet: Wallet(
                        name: name, origin: .seed,
                        accounts: [WalletAccount(ecosystem: .substrate, cryptoType: options.substrateCryptoType, publicKey: Data(account), derivationPath: nil)],
                        createdAt: now, isBackedUp: true
                    ),
                    substrateAccount: account, substrateAddresses: [:], evmAddress: nil, phrase: nil
                )
            case .evm:
                let evm = PreviewAddressCodec.fakeEVMAddress(seed: seed)
                return StoredWallet(
                    wallet: Wallet(
                        name: name, origin: .seed,
                        accounts: [WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: Data(PreviewBIP39.bytes(fromHex: String(evm.dropFirst(2)))), derivationPath: nil)],
                        createdAt: now, isBackedUp: true
                    ),
                    substrateAccount: nil, substrateAddresses: [:], evmAddress: evm, phrase: nil
                )
            }
        case let .json(data, password):
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw WalletError.invalidJSON("the file is not a JSON keystore.")
            }
            guard let address = object["address"] as? String, object["encoded"] != nil else {
                throw WalletError.invalidJSON("it has no address or encoded key.")
            }
            guard !password.isEmpty, password != "wrong" else { throw WalletError.wrongJSONPassword }
            if PreviewAddressCodec.isEVMAddress(address) {
                return StoredWallet(
                    wallet: Wallet(
                        name: name, origin: .json,
                        accounts: [WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: Data(PreviewBIP39.bytes(fromHex: String(address.dropFirst(2)))), derivationPath: nil)],
                        createdAt: now, isBackedUp: true
                    ),
                    substrateAccount: nil, substrateAddresses: [:], evmAddress: address, phrase: nil
                )
            }
            guard let bytes = PreviewAddressCodec.base58Decode(address), bytes.count == 35 else {
                throw WalletError.invalidJSON("its address is not valid.")
            }
            let account = Array(bytes[1..<33])
            return StoredWallet(
                wallet: Wallet(
                    name: name, origin: .json,
                    accounts: [WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(account), derivationPath: nil)],
                    createdAt: now, isBackedUp: true
                ),
                substrateAccount: account, substrateAddresses: [:], evmAddress: nil, phrase: nil
            )
        case let .watchOnly(substrateAddress, evmAddress):
            let substrate = substrateAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            let evm = evmAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            var accounts: [WalletAccount] = []
            var account: [UInt8]?
            if let substrate, !substrate.isEmpty {
                guard let bytes = PreviewAddressCodec.base58Decode(substrate), bytes.count == 35, (46...49).contains(substrate.count) else {
                    throw WalletError.invalidAddress("That is not a valid Polkadot-ecosystem address.")
                }
                account = Array(bytes[1..<33])
                accounts.append(WalletAccount(ecosystem: .substrate, cryptoType: .sr25519, publicKey: Data(bytes[1..<33]), derivationPath: nil))
            }
            var evmValue: String?
            if let evm, !evm.isEmpty {
                guard PreviewAddressCodec.isEVMAddress(evm) else {
                    throw WalletError.invalidAddress("That is not a valid Ethereum address.")
                }
                evmValue = evm
                accounts.append(WalletAccount(ecosystem: .evm, cryptoType: .ecdsa, publicKey: Data(PreviewBIP39.bytes(fromHex: String(evm.dropFirst(2)))), derivationPath: nil))
            }
            guard !accounts.isEmpty else { throw WalletError.invalidAddress("Enter at least one address to watch.") }
            return StoredWallet(
                wallet: Wallet(name: name, origin: .watchOnly, accounts: accounts, createdAt: now, isBackedUp: true),
                substrateAccount: account, substrateAddresses: [:], evmAddress: evmValue, phrase: nil
            )
        }
    }
}

struct PreviewCatalogService: ChainCatalogServicing {
    let store: PreviewStore

    func chains() async -> [Chain] {
        await store.pause(scale: 0.3)
        return PreviewCatalog.chains
    }

    func assets() async -> [Asset] {
        await store.pause(scale: 0.3)
        return PreviewCatalog.assets
    }
}

struct PreviewNodeService: NodeServicing {
    let store: PreviewStore

    func nodes(for chainID: ChainID) async -> [ChainNode] {
        await store.nodes(for: chainID)
    }

    func selectedNode(for chainID: ChainID) async -> ChainNode? {
        await store.selectedNode(for: chainID)
    }

    func selectNode(_ node: ChainNode?, for chainID: ChainID) async {
        await store.selectNode(node, for: chainID)
    }

    func addCustomNode(name: String, url: URL, for chainID: ChainID) async throws -> ChainNode {
        await store.pause(scale: 1.5)
        return try await store.addCustomNode(name: name, url: url, for: chainID)
    }

    func removeCustomNode(_ node: ChainNode, for chainID: ChainID) async {
        await store.removeCustomNode(node, for: chainID)
    }
}

struct PreviewBalanceService: BalanceServicing {
    let store: PreviewStore

    func balances(of walletID: WalletID, assets: [AssetID]) async -> [AssetID: Result<AssetBalance, WalletError>] {
        await store.pause(scale: 1.4)
        var result: [AssetID: Result<AssetBalance, WalletError>] = [:]
        for asset in assets {
            result[asset] = await store.balance(of: walletID, asset: asset)
        }
        return result
    }
}

struct PreviewPriceService: PriceServicing {
    let store: PreviewStore

    func prices(for priceIDs: Set<String>, in currency: FiatCurrency) async throws -> [String: AssetPrice] {
        await store.pause()
        if store.scenario.pricesFail {
            throw WalletError.network("The price service did not answer.")
        }
        let rate = PreviewSampleData.usdRates[currency.code] ?? 1
        var result: [String: AssetPrice] = [:]
        for id in priceIDs {
            guard let sample = PreviewSampleData.usdPrices[id] else { continue }
            result[id] = AssetPrice(priceID: id, currency: currency, value: sample.price * rate, change24h: sample.change)
        }
        return result
    }
}

struct PreviewActivityService: ActivityServicing {
    let store: PreviewStore

    func activity(of walletID: WalletID, assets: [AssetID]?) async throws -> ActivityPage {
        await store.pause(scale: 1.2)
        _ = try await store.stored(walletID)
        return await store.history(of: walletID, assets: assets)
    }
}
