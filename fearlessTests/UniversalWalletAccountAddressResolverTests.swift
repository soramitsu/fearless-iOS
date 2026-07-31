import SSFModels
import XCTest
@testable import fearless

final class UniversalWalletAccountAddressResolverTests: XCTestCase {
    func testResolvesBitcoinMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let key = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        )
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: key.publicKey
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, key.address)
        XCTAssertTrue(address?.hasPrefix("bc1") == true)
    }

    func testResolvesBitcoinTestnetAddressFromMatchingChainAccountPublicKey() throws {
        let key = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive,
            network: .testnet
        )
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinTestnet.chainId,
            publicKey: key.publicKey
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinTestnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, key.address)
        XCTAssertTrue(address?.hasPrefix("tb1") == true)
    }

    func testBitcoinAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testBitcoinAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: Data(repeating: 0x01, count: 32)
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testResolvesSolanaMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testResolvesSolanaDevnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaDevnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaDevnet.chainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testSolanaAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testResolvesRealTonMainnetAddressFromMatchingChainAccountPublicKey() throws {
        let account = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: TonChainSelection.mainnetChainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(TonChainSelection.mainnetChainId),
            wallet: wallet
        )

        XCTAssertEqual(address, account.addressNonBounceable)
    }

    func testTonAddressResolutionRejectsMissingMalformedAndTestnetAccounts() throws {
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: AccountGenerator.generateMetaAccount()
            )
        )

        let malformed = walletWithChainAccount(
            chainId: TonChainSelection.mainnetChainId,
            publicKey: Data(repeating: 1, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: malformed
            )
        )

        let account = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let testnetOnly = walletWithChainAccount(
            chainId: TonChainSelection.testnetChainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        XCTAssertNil(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(TonChainSelection.mainnetChainId),
                wallet: testnetOnly
            )
        )
    }

    func testSolanaAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: Data(repeating: 0x01, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testResolverMatchesCanonicalSolanaAccountWhenChainUsesRegistryId() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.solanaMainnet.id),
            wallet: wallet
        )

        XCTAssertEqual(address, account.address)
    }

    func testResolvesTairaI105AddressFromMatchingChainAccountPublicKey() throws {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(UniversalWalletRegistry.taira.chainId),
                wallet: wallet
            )
        )

        XCTAssertTrue(address.hasPrefix("test"))
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            ).publicKeyHex,
            account.publicKeyHex
        )
    }

    func testResolvesNexusI105AddressFromSamePublicKeyWithNexusDiscriminant() throws {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.nexus.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(
                for: Self.chain(UniversalWalletRegistry.nexus.chainId),
                wallet: wallet
            )
        )

        XCTAssertTrue(address.hasPrefix("sora"))
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            ).publicKeyHex,
            account.publicKeyHex
        )
        XCTAssertThrowsError(
            try IrohaAddressCodec.parse(
                address,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
        )
    }

    func testIrohaAddressResolutionFailsClosedWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.taira.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testIrohaAddressResolutionRejectsMalformedPublicKey() {
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.taira.chainId,
            publicKey: Data(repeating: 0x01, count: 31),
            cryptoType: CryptoType.ed25519.rawValue
        )

        let address = UniversalWalletAccountAddressResolver.address(
            for: Self.chain(UniversalWalletRegistry.taira.chainId),
            wallet: wallet
        )

        XCTAssertNil(address)
    }

    func testFetchFailsClosedForUniversalWalletChainWithoutMatchingChainAccount() {
        let wallet = AccountGenerator.generateMetaAccount()

        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.solanaMainnet.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(UniversalWalletRegistry.taira.chainId).accountRequest()))
        XCTAssertNil(wallet.fetch(for: Self.chain(TonChainSelection.mainnetChainId).accountRequest()))
    }

    func testFetchMatchesRegistryIdToCanonicalUniversalWalletChainAccount() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        let response = try XCTUnwrap(
            wallet.fetch(for: Self.chain(UniversalWalletRegistry.solanaMainnet.id).accountRequest())
        )

        XCTAssertEqual(response.chainId, UniversalWalletRegistry.solanaMainnet.id)
        XCTAssertEqual(response.toAddress(), account.address)
    }

    func testChainAccountResponseDerivesUniversalWalletNativeAddresses() throws {
        let bitcoinKey = try BitcoinKeyDerivation.deriveKey(
            mnemonic: Self.mnemonic,
            derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            network: .mainnet
        )
        let bitcoinWallet = walletWithBitcoinAccount(
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            publicKey: bitcoinKey.publicKey
        )
        XCTAssertEqual(
            bitcoinWallet.fetch(for: Self.chain(UniversalWalletRegistry.bitcoinMainnet.chainId).accountRequest())?.toAddress(),
            bitcoinKey.address
        )

        let irohaAccount = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let irohaWallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.nexus.chainId,
            publicKey: irohaAccount.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        let irohaAddress = try XCTUnwrap(
            irohaWallet.fetch(for: Self.chain(UniversalWalletRegistry.nexus.id).accountRequest())?.toAddress()
        )
        XCTAssertEqual(
            try IrohaAddressCodec.parse(
                irohaAddress,
                expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            ).publicKeyHex,
            irohaAccount.publicKeyHex
        )
    }

    func testAccountFetchingFindsUniversalWalletByNativeAddressOnlyOnMatchingChain() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )

        var result: Result<ChainAccountResponse?, Error>?
        let found = AccountFetchingHarness().fetchChainAccountFor(
            meta: wallet,
            chain: Self.chain(UniversalWalletRegistry.solanaMainnet.id),
            address: account.address
        ) { result = $0 }

        XCTAssertTrue(found)
        XCTAssertEqual(try result?.get()?.toAddress(), account.address)
    }

    func testAccountFetchingDoesNotExposeUniversalWalletAccountAsSubstrate() throws {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let wallet = walletWithChainAccount(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue
        )
        let substrateChain = Self.chain(String(repeating: "a", count: 64))
        let substrateFormattedSolanaKey = try account.publicKey.toAddress(
            using: .substrate(substrateChain.addressPrefix)
        )

        var result: Result<ChainAccountResponse?, Error>?
        let found = AccountFetchingHarness().fetchChainAccountFor(
            meta: wallet,
            chain: substrateChain,
            address: substrateFormattedSolanaKey
        ) { result = $0 }

        XCTAssertFalse(found)
        XCTAssertThrowsError(try result?.get())
    }

    func testNonBitcoinChainsKeepExistingAddressResolution() {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = Self.chain(String(repeating: "0", count: 64))

        let address = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet)

        XCTAssertEqual(address, wallet.fetch(for: chain.accountRequest())?.toAddress())
    }

    private func walletWithBitcoinAccount(chainId: String, publicKey: Data) -> MetaAccountModel {
        walletWithChainAccount(
            chainId: chainId,
            publicKey: publicKey,
            cryptoType: CryptoType.ecdsa.rawValue
        )
    }

    private func walletWithChainAccount(chainId: String, publicKey: Data, cryptoType: UInt8) -> MetaAccountModel {
        let account = ChainAccountModel(
            chainId: chainId,
            accountId: publicKey,
            publicKey: publicKey,
            cryptoType: cryptoType,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [account])
    }

    private static func chain(_ chainId: String) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Test",
            assets: [],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://node.example")!,
                    name: "Test",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            icon: nil,
            options: nil,
            externalApi: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static let mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
}

private final class AccountFetchingHarness: AccountFetching {}
