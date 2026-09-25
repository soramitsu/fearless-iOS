import Foundation
import IrohaCrypto
import SSFModels
import TonSwift

extension IOSPortableWalletSemanticDraftAdapter {
    static func substrateRoot(from entry: IOSPasskeyWalletMaterialDraft.Wallet) throws -> Codec.Slot? {
        let identity = entry.publicIdentity
        if let publicKey = identity.substratePublicKey,
           let accountID = identity.substrateAccountId {
            let secret = try required(.substrateSecret, in: entry)
            var fields = [
                field(FieldID.publicKey, publicKey), field(FieldID.privateKey, secret),
                field(FieldID.accountIDOrAddress, accountID),
                field(FieldID.cryptoType, [try cryptoType(identity.substrateCryptoType)]),
                field(FieldID.sourceRecipe, [0])
            ]
            append(.entropy, fieldID: FieldID.entropy, from: entry, to: &fields)
            append(.substrateSeed, fieldID: FieldID.seed, from: entry, to: &fields)
            append(.substrateDerivation, fieldID: FieldID.derivationPath, from: entry, to: &fields)
            return slot(Role.substrateRoot, "", fields)
        }
        guard identity.substratePublicKey == nil, identity.substrateAccountId == nil else {
            throw AdapterError.unrepresentableDraft
        }
        return nil
    }

    static func evmRoot(from entry: IOSPasskeyWalletMaterialDraft.Wallet) throws -> Codec.Slot? {
        let identity = entry.publicIdentity
        if let publicKey = identity.ethereumPublicKey,
           let address = identity.ethereumAddress {
            let secret = try required(.ethereumSecret, in: entry)
            var fields = [
                field(FieldID.publicKey, publicKey), field(FieldID.privateKey, secret),
                field(FieldID.accountIDOrAddress, address), field(FieldID.sourceRecipe, [0])
            ]
            if identity.canExportEthereumMnemonic,
               value(.ethereumDerivation, in: entry) != nil {
                append(.entropy, fieldID: FieldID.entropy, from: entry, to: &fields)
            }
            append(.ethereumSeed, fieldID: FieldID.seed, from: entry, to: &fields)
            append(.ethereumDerivation, fieldID: FieldID.derivationPath, from: entry, to: &fields)
            return slot(Role.evmRoot, "", fields)
        }
        guard identity.ethereumPublicKey == nil, identity.ethereumAddress == nil else {
            throw AdapterError.unrepresentableDraft
        }
        return nil
    }

    static func tonRoot(
        _ native: LegacyTonAccount,
        from entry: IOSPasskeyWalletMaterialDraft.Wallet
    ) throws -> Codec.Slot {
        guard native.contractVersion == "v4R2",
              let phrase = value(.entropy, in: entry),
              let verified = try? native.mnemonic(from: phrase) else {
            throw AdapterError.unrepresentableDraft
        }
        let secret: Data
        if let stored = value(.tonSecret, in: entry) {
            secret = try native.validatedPrivateKey(stored)
        } else {
            let recovered = try TonSwift.Mnemonic.mnemonicToPrivateKey(
                mnemonicArray: verified.allWords()
            ).privateKey.data
            secret = try native.validatedPrivateKey(recovered)
        }
        return slot(Role.tonRoot, "", [
            field(FieldID.publicKey, native.publicKey),
            field(FieldID.privateKey, secret),
            field(FieldID.accountIDOrAddress, native.serializedAddress),
            field(FieldID.sourceRecipe, [0]),
            field(FieldID.mnemonic, phrase),
            field(FieldID.tonContractVersion, [2]),
            field(FieldID.tonAddressEncoding, [2])
        ])
    }

    static func chainSlot(
        _ account: ChainAccountModel,
        from entry: IOSPasskeyWalletMaterialDraft.Wallet
    ) throws -> Codec.Slot {
        guard !account.chainId.isEmpty, !account.accountId.isEmpty,
              !account.publicKey.isEmpty else { throw AdapterError.unrepresentableDraft }
        let keyRole: DraftSlot.Role = account.ethereumBased ? .ethereumSecret : .substrateSecret
        let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: account.chainId)
        let rootDerived = [
            UniversalWalletRegistry.bitcoinMainnet.chainId,
            UniversalWalletRegistry.bitcoinTestnet.chainId,
            UniversalWalletRegistry.taira.chainId
        ].contains(canonical)
        // Released Bitcoin/Taira signers use the named root derivation. A stray
        // scoped Keychain item is retained below as auxiliary history, but it
        // cannot replace the canonical signing key.
        let secret: Data
        if rootDerived {
            secret = try derivedChainKey(account, from: entry)
        } else {
            secret = try value(keyRole, in: entry, chainId: account.chainId, accountID: account.accountId)
                ?? derivedChainKey(account, from: entry)
        }
        var fields = [
            field(FieldID.publicKey, account.publicKey),
            field(FieldID.privateKey, secret),
            field(FieldID.accountIDOrAddress, account.accountId),
            field(FieldID.cryptoType, [try cryptoType(account.cryptoType)]),
            // iOS persists no per-chain name or initialized flag.
            field(FieldID.chainName, Data()),
            field(FieldID.initializedOrFavorite, [1]),
            field(FieldID.sourceRecipe, [0])
        ]
        append(
            .entropy,
            fieldID: FieldID.entropy,
            from: entry,
            to: &fields,
            chainId: account.chainId,
            accountID: account.accountId
        )
        append(
            account.ethereumBased ? .ethereumSeed : .substrateSeed,
            fieldID: FieldID.seed,
            from: entry,
            to: &fields,
            chainId: account.chainId,
            accountID: account.accountId
        )
        append(
            account.ethereumBased ? .ethereumDerivation : .substrateDerivation,
            fieldID: FieldID.derivationPath,
            from: entry,
            to: &fields,
            chainId: account.chainId,
            accountID: account.accountId
        )
        return slot(Role.chainAccount, account.chainId, fields)
    }

    static func derivedChainKey(
        _ account: ChainAccountModel,
        from entry: IOSPasskeyWalletMaterialDraft.Wallet
    ) throws -> Data {
        guard let mnemonic = try rootMnemonic(from: entry) else {
            throw AdapterError.unrepresentableDraft
        }
        let canonical = UniversalWalletChainAccountSupport.canonicalChainId(for: account.chainId)
        let privateKey: Data
        let publicKey: Data
        switch canonical {
        case UniversalWalletRegistry.bitcoinMainnet.chainId,
             UniversalWalletRegistry.bitcoinTestnet.chainId:
            let network: BitcoinKeyDerivation.Network = canonical == UniversalWalletRegistry.bitcoinMainnet.chainId
                ? .mainnet : .testnet
            let derived = try BitcoinKeyDerivation.deriveAccount(mnemonic: mnemonic, network: network)
            privateKey = derived.privateKey
            publicKey = derived.publicKey
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.nexus.chainId:
            let derived = try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic)
            privateKey = derived.privateKey
            publicKey = derived.publicKey
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaDevnet.chainId:
            let derived = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
            privateKey = derived.privateKey
            publicKey = derived.publicKey
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            let derived = try TonKeyDerivation.deriveAccount(mnemonic: mnemonic)
            privateKey = derived.privateKey
            publicKey = derived.publicKey
        default:
            throw AdapterError.unrepresentableDraft
        }
        guard publicKey == account.publicKey else { throw AdapterError.unrepresentableDraft }
        return privateKey
    }

    static func rootMnemonic(from entry: IOSPasskeyWalletMaterialDraft.Wallet) throws -> String? {
        guard entry.publicIdentity.substratePublicKey != nil else { return nil }
        if let entropy = value(.entropy, in: entry) {
            return try IRMnemonicCreator().mnemonic(fromEntropy: entropy).toString()
        }
        if let source = value(.universalWalletSource, in: entry),
           let seed = value(.substrateSeed, in: entry),
           String(data: source, encoding: .utf8) == UniversalWalletSeedBridge.contract {
            return try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: seed)
        }
        return nil
    }
}
