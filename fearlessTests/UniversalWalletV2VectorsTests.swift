import XCTest
@testable import fearless

final class UniversalWalletV2VectorsTests: XCTestCase {
    func testGoldenVectorsDefineEveryUniversalWalletEcosystem() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(fixture.version, 1)
        XCTAssertEqual(fixture.vectors.map(\.id), ["import12", "default24"])
        XCTAssertEqual(
            Set(fixture.negativeCases.map(\.id)),
            ["bitcoin-wrong-purpose", "solana-wrong-path", "iroha-wrong-discriminant", "ton-testnet-flag"]
        )
        XCTAssertEqual(
            Set(UniversalWalletEcosystem.allCases.map(\.rawValue)),
            ["substrate", "evm", "ton", "bitcoin", "solana", "iroha"]
        )

        for vector in fixture.vectors {
            XCTAssertEqual(vector.mnemonic.split(separator: " ").count, vector.wordCount)
            XCTAssertTrue([12, 24].contains(vector.wordCount))
            XCTAssertEqual(Set(vector.expected.keys), ["substrate", "evm", "bitcoin", "solana", "ton", "iroha"])

            let substrate = try XCTUnwrap(vector.expected["substrate"] as? [String: Any])
            XCTAssertEqual(substrate["cryptoType"] as? String, "sr25519")
            XCTAssertEqual(substrate["ss58Prefix"] as? Int, 0)
            assertHex(try XCTUnwrap(substrate["publicKeyHex"] as? String), byteLength: 32)
            XCTAssertTrue(try XCTUnwrap(substrate["polkadotAddress"] as? String).hasPrefix("1"))

            let evm = try XCTUnwrap(vector.expected["evm"] as? [String: Any])
            XCTAssertEqual(evm["derivationPath"] as? String, "m/44'/60'/0'/0/0")
            assertMatches(try XCTUnwrap(evm["address"] as? String), pattern: "^0x[0-9a-fA-F]{40}$")

            try assertBitcoin(try XCTUnwrap(vector.expected["bitcoin"] as? [String: Any]))
            try assertSolana(try XCTUnwrap(vector.expected["solana"] as? [String: Any]))
            try assertTon(try XCTUnwrap(vector.expected["ton"] as? [String: Any]))
            try assertIroha(try XCTUnwrap(vector.expected["iroha"] as? [String: Any]))
        }
    }

    func testNetworkSpecificFixtureValuesCannotBeSilentlyReused() throws {
        for vector in try loadFixture().vectors {
            let bitcoin = try XCTUnwrap(vector.expected["bitcoin"] as? [String: Any])
            let mainnet = try XCTUnwrap(bitcoin["mainnet"] as? [String: Any])
            let testnet = try XCTUnwrap(bitcoin["testnet"] as? [String: Any])
            let mainnetAddress = try XCTUnwrap(mainnet["firstReceiveAddress"] as? String)
            let testnetAddress = try XCTUnwrap(testnet["firstReceiveAddress"] as? String)
            XCTAssertTrue(mainnetAddress.hasPrefix("bc1q"))
            XCTAssertTrue(testnetAddress.hasPrefix("tb1q"))
            XCTAssertNotEqual(mainnetAddress, testnetAddress)

            let ton = try XCTUnwrap(vector.expected["ton"] as? [String: Any])
            let tonMainnet = try XCTUnwrap(ton["addressNonBounceable"] as? String)
            let tonTestnet = try XCTUnwrap(ton["testnetNonBounceable"] as? String)
            XCTAssertTrue(tonMainnet.hasPrefix("UQ"))
            XCTAssertTrue(tonTestnet.hasPrefix("0Q"))
            XCTAssertNotEqual(tonMainnet, tonTestnet)

            let iroha = try XCTUnwrap(vector.expected["iroha"] as? [String: Any])
            let taira = try XCTUnwrap(iroha["taira"] as? [String: Any])
            let nexus = try XCTUnwrap(iroha["nexus"] as? [String: Any])
            XCTAssertEqual(taira["canonicalHex"] as? String, nexus["canonicalHex"] as? String)
            XCTAssertEqual(taira["chainDiscriminant"] as? Int, 369)
            XCTAssertEqual(nexus["chainDiscriminant"] as? Int, 753)
            XCTAssertTrue(try XCTUnwrap(taira["i105"] as? String).hasPrefix("test"))
            XCTAssertTrue(try XCTUnwrap(nexus["i105"] as? String).hasPrefix("sora"))
            XCTAssertNotEqual(taira["i105"] as? String, nexus["i105"] as? String)
        }
    }

    func testRegistryDefinesPublicIndexersAndGatedIrohaNetworks() {
        XCTAssertEqual(UniversalWalletRegistry.tonIndexerBaseURL.absoluteString, "https://ti.soramitsu.io")
        XCTAssertEqual(UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString, "https://si.soramitsu.io")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL.absoluteString, "https://mempool.space/api")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnetIndexerBaseURL.absoluteString, "https://mempool.space/testnet/api")

        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.id, "bitcoin-mainnet")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.chainId, "bitcoin:mainnet")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.name, "Bitcoin")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.slip44CoinType, 0)
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.addressHrp, "bc")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.accountPath, "m/84'/0'/0'")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.firstReceivePath, "m/84'/0'/0'/0/0")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.indexerBaseURL.absoluteString, "https://mempool.space/api")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit, 20)
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.nativeAsset.id, "BTC")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.nativeAsset.symbol, "BTC")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinMainnet.nativeAsset.decimals, 8)
        XCTAssertTrue(UniversalWalletRegistry.bitcoinMainnet.enabledByDefault)

        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.id, "bitcoin-testnet")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.chainId, "bitcoin:testnet")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.name, "Bitcoin Testnet")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.slip44CoinType, 1)
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.addressHrp, "tb")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.accountPath, "m/84'/1'/0'")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.firstReceivePath, "m/84'/1'/0'/0/0")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.indexerBaseURL.absoluteString, "https://mempool.space/testnet/api")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.defaultGapLimit, 20)
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.nativeAsset.id, "BTC")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.nativeAsset.symbol, "BTC")
        XCTAssertEqual(UniversalWalletRegistry.bitcoinTestnet.nativeAsset.decimals, 8)
        XCTAssertFalse(UniversalWalletRegistry.bitcoinTestnet.enabledByDefault)

        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.id, "solana-mainnet")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.chainId, "solana:mainnet")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.name, "Solana")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.indexerBaseURL.absoluteString, "https://si.soramitsu.io")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.rpcURL.absoluteString, "https://api.mainnet-beta.solana.com")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.nativeAsset.id, "SOL")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.nativeAsset.symbol, "SOL")
        XCTAssertEqual(UniversalWalletRegistry.solanaMainnet.nativeAsset.decimals, 9)
        XCTAssertTrue(UniversalWalletRegistry.solanaMainnet.enabledByDefault)

        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.id, "solana-devnet")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.chainId, "solana:devnet")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.name, "Solana Devnet")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.indexerBaseURL.absoluteString, "https://si.soramitsu.io")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.rpcURL.absoluteString, "https://api.devnet.solana.com")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.nativeAsset.id, "SOL")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.nativeAsset.symbol, "SOL")
        XCTAssertEqual(UniversalWalletRegistry.solanaDevnet.nativeAsset.decimals, 9)
        XCTAssertFalse(UniversalWalletRegistry.solanaDevnet.enabledByDefault)

        XCTAssertEqual(UniversalWalletRegistry.taira.id, "taira-testnet")
        XCTAssertEqual(UniversalWalletRegistry.taira.chainId, "iroha3-taira")
        XCTAssertEqual(UniversalWalletRegistry.taira.chainDiscriminant, 369)
        XCTAssertEqual(UniversalWalletRegistry.taira.toriiBaseURL?.absoluteString, "https://taira.sora.org")
        XCTAssertEqual(UniversalWalletRegistry.taira.mcpPath, "/v1/mcp")
        XCTAssertEqual(UniversalWalletRegistry.taira.mcpEndpointURL?.absoluteString, "https://taira.sora.org/v1/mcp")
        XCTAssertTrue(UniversalWalletRegistry.taira.enabledByDefault)

        XCTAssertEqual(UniversalWalletRegistry.nexus.id, "sora-nexus-mainnet")
        XCTAssertEqual(UniversalWalletRegistry.nexus.chainId, "sora:nexus:global")
        XCTAssertEqual(UniversalWalletRegistry.nexus.chainDiscriminant, 753)
        XCTAssertEqual(UniversalWalletRegistry.nexus.toriiBaseURL?.absoluteString, "https://minamoto.sora.org")
        XCTAssertEqual(UniversalWalletRegistry.nexus.mcpPath, "/v1/mcp")
        XCTAssertEqual(UniversalWalletRegistry.nexus.mcpEndpointURL?.absoluteString, "https://minamoto.sora.org/v1/mcp")
        XCTAssertFalse(UniversalWalletRegistry.nexus.enabledByDefault)
    }

    func testDerivationConstantsMatchFixtureDefaults() throws {
        let expected = try XCTUnwrap(try loadFixture().vectors.first?.expected)
        let substrate = try XCTUnwrap(expected["substrate"] as? [String: Any])
        let evm = try XCTUnwrap(expected["evm"] as? [String: Any])
        let bitcoin = try XCTUnwrap(expected["bitcoin"] as? [String: Any])
        let bitcoinMainnet = try XCTUnwrap(bitcoin["mainnet"] as? [String: Any])
        let bitcoinTestnet = try XCTUnwrap(bitcoin["testnet"] as? [String: Any])
        let solana = try XCTUnwrap(expected["solana"] as? [String: Any])
        let ton = try XCTUnwrap(expected["ton"] as? [String: Any])
        let iroha = try XCTUnwrap(expected["iroha"] as? [String: Any])

        XCTAssertEqual(substrate["derivationPath"] as? String, UniversalWalletDerivationPaths.substrateRoot)
        XCTAssertEqual(evm["derivationPath"] as? String, UniversalWalletDerivationPaths.evmDefault)
        XCTAssertEqual(bitcoinMainnet["accountPath"] as? String, UniversalWalletDerivationPaths.bitcoinMainnetAccount)
        XCTAssertEqual(bitcoinMainnet["firstReceivePath"] as? String, UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive)
        XCTAssertEqual(bitcoinTestnet["accountPath"] as? String, UniversalWalletDerivationPaths.bitcoinTestnetAccount)
        XCTAssertEqual(bitcoinTestnet["firstReceivePath"] as? String, UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive)
        XCTAssertEqual(solana["derivationPath"] as? String, UniversalWalletDerivationPaths.solanaDefault)
        XCTAssertEqual(ton["derivationPath"] as? String, UniversalWalletDerivationPaths.tonDefault)
        XCTAssertEqual(iroha["derivationPath"] as? String, UniversalWalletDerivationPaths.irohaDefault)
    }

    func testBitcoinKeyDerivationMatchesGoldenVectors() throws {
        for vector in try loadFixture().vectors {
            let expected = try XCTUnwrap(vector.expected["bitcoin"] as? [String: Any])
            let expectedMainnet = try XCTUnwrap(expected["mainnet"] as? [String: Any])
            let expectedTestnet = try XCTUnwrap(expected["testnet"] as? [String: Any])
            let mainnet = try BitcoinKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, network: .mainnet)
            let testnet = try BitcoinKeyDerivation.deriveAccount(mnemonic: vector.mnemonic, network: .testnet)

            XCTAssertEqual(mainnet.network, .mainnet)
            XCTAssertEqual(mainnet.accountPath, UniversalWalletDerivationPaths.bitcoinMainnetAccount)
            XCTAssertEqual(mainnet.firstReceivePath, UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive)
            XCTAssertEqual(mainnet.accountXpub, expectedMainnet["accountXpub"] as? String)
            XCTAssertEqual(mainnet.firstReceiveAddress, expectedMainnet["firstReceiveAddress"] as? String)
            XCTAssertEqual(mainnet.privateKey.count, 32)
            XCTAssertEqual(mainnet.chainCode.count, 32)
            XCTAssertEqual(mainnet.publicKey.count, 33)

            XCTAssertEqual(testnet.network, .testnet)
            XCTAssertEqual(testnet.accountPath, UniversalWalletDerivationPaths.bitcoinTestnetAccount)
            XCTAssertEqual(testnet.firstReceivePath, UniversalWalletDerivationPaths.bitcoinTestnetFirstReceive)
            XCTAssertEqual(testnet.accountXpub, expectedTestnet["accountXpub"] as? String)
            XCTAssertEqual(testnet.firstReceiveAddress, expectedTestnet["firstReceiveAddress"] as? String)
            XCTAssertEqual(testnet.privateKey.count, 32)
            XCTAssertEqual(testnet.chainCode.count, 32)
            XCTAssertEqual(testnet.publicKey.count, 33)
        }
    }

    func testBitcoinKeyDerivationNormalizesMnemonicWhitespace() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["bitcoin"] as? [String: Any])
        let expectedMainnet = try XCTUnwrap(expected["mainnet"] as? [String: Any])
        let paddedMnemonic = "  \(vector.mnemonic.replacingOccurrences(of: " ", with: "   \n\t"))  "

        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: paddedMnemonic, network: .mainnet)

        XCTAssertEqual(account.accountXpub, expectedMainnet["accountXpub"] as? String)
        XCTAssertEqual(account.firstReceiveAddress, expectedMainnet["firstReceiveAddress"] as? String)
    }

    func testBitcoinKeyDerivationDoesNotReuseAddressesAcrossPathsOrPassphrases() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["bitcoin"] as? [String: Any])
        let expectedMainnet = try XCTUnwrap(expected["mainnet"] as? [String: Any])
        let wrongPurpose = try BitcoinKeyDerivation.deriveKey(
            mnemonic: vector.mnemonic,
            derivationPath: "m/44'/0'/0'/0/0",
            network: .mainnet
        )
        let withPassphrase = try BitcoinKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            passphrase: "fearless",
            network: .mainnet
        )

        XCTAssertNotEqual(wrongPurpose.address, expectedMainnet["firstReceiveAddress"] as? String)
        XCTAssertNotEqual(withPassphrase.accountXpub, expectedMainnet["accountXpub"] as? String)
        XCTAssertNotEqual(withPassphrase.firstReceiveAddress, expectedMainnet["firstReceiveAddress"] as? String)
    }

    func testBitcoinKeyDerivationBuildsReceivePathsSafely() throws {
        XCTAssertEqual(try BitcoinKeyDerivation.getReceivePath(network: .mainnet, index: 7), "m/84'/0'/0'/0/7")
        XCTAssertEqual(try BitcoinKeyDerivation.getReceivePath(network: .testnet, index: 7), "m/84'/1'/0'/0/7")
        XCTAssertEqual(try BitcoinKeyDerivation.getReceivePath(network: .mainnet, index: 2, change: 1), "m/84'/0'/0'/1/2")

        XCTAssertThrowsError(try BitcoinKeyDerivation.getReceivePath(network: .mainnet, index: UInt32.max))
        XCTAssertThrowsError(try BitcoinKeyDerivation.getReceivePath(network: .mainnet, index: 0, change: 2))
    }

    func testBitcoinKeyDerivationRejectsMalformedInputs() throws {
        let seed = Data(repeating: 1, count: 64)

        XCTAssertThrowsError(try BitcoinKeyDerivation.deriveAccount(mnemonic: ""))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: Data(), derivationPath: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: seed, derivationPath: ""))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: seed, derivationPath: "84'/0'/0'/0/0"))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: seed, derivationPath: "m/84'//0'"))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: seed, derivationPath: "m/84'/x'/0'"))
        XCTAssertThrowsError(try BitcoinKeyDerivation.derivePrivateKey(seed: seed, derivationPath: "m/84'/2147483648'/0'"))
        XCTAssertThrowsError(try BitcoinKeyDerivation.publicKey(fromPrivateKey: Data(repeating: 0, count: 31)))
        XCTAssertThrowsError(try BitcoinKeyDerivation.publicKey(fromPrivateKey: Data(repeating: 0, count: 32)))
        XCTAssertThrowsError(try BitcoinKeyDerivation.address(fromPublicKey: Data(repeating: 0, count: 32), network: .mainnet))
    }

    func testSolanaKeyDerivationMatchesGoldenVectors() throws {
        for vector in try loadFixture().vectors {
            let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
            let account = try SolanaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic)

            XCTAssertEqual(account.derivationPath, UniversalWalletDerivationPaths.solanaDefault)
            XCTAssertEqual(account.publicKey.hexString, expected["publicKeyHex"] as? String)
            XCTAssertEqual(account.address, expected["address"] as? String)
            XCTAssertEqual(account.privateKey.count, 32)
            XCTAssertEqual(account.chainCode.count, 32)
        }
    }

    func testSolanaKeyDerivationNormalizesMnemonicWhitespace() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let paddedMnemonic = "  \(vector.mnemonic.replacingOccurrences(of: " ", with: "   \n\t"))  "

        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: paddedMnemonic)

        XCTAssertEqual(account.publicKey.hexString, expected["publicKeyHex"] as? String)
        XCTAssertEqual(account.address, expected["address"] as? String)
    }

    func testSolanaKeyDerivationDoesNotReuseAddressesAcrossPathsOrPassphrases() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let wrongPath = try SolanaKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            derivationPath: "m/44'/501'/1'/0'"
        )
        let withPassphrase = try SolanaKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            passphrase: "fearless"
        )

        XCTAssertNotEqual(wrongPath.publicKey.hexString, expected["publicKeyHex"] as? String)
        XCTAssertNotEqual(wrongPath.address, expected["address"] as? String)
        XCTAssertNotEqual(withPassphrase.publicKey.hexString, expected["publicKeyHex"] as? String)
        XCTAssertNotEqual(withPassphrase.address, expected["address"] as? String)
    }

    func testSolanaKeyDerivationRejectsMalformedInputs() throws {
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: ""))
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: "abandon abandon abandon", derivationPath: ""))
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: "abandon abandon abandon", derivationPath: "44'/501'/0'/0'"))
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: "abandon abandon abandon", derivationPath: "m/44'/501/0'/0'"))
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: "abandon abandon abandon", derivationPath: "m/44'/501'/x'/0'"))
        XCTAssertThrowsError(try SolanaKeyDerivation.deriveAccount(mnemonic: "abandon abandon abandon", derivationPath: "m/44'/501'/2147483648'/0'"))
        XCTAssertThrowsError(try SolanaKeyDerivation.derivePrivateKey(seed: Data(), derivationPath: UniversalWalletDerivationPaths.solanaDefault))
        XCTAssertThrowsError(try SolanaKeyDerivation.publicKey(fromPrivateKey: Data(repeating: 0, count: 31)))
        XCTAssertThrowsError(try SolanaKeyDerivation.address(fromPublicKey: Data(repeating: 0, count: 31)))
        XCTAssertFalse(try SolanaKeyDerivation.address(fromPublicKey: Data(repeating: 0, count: 32)).isEmpty)
    }

    func testSolanaSignerProducesVerifiableSignatures() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["solana"] as? [String: Any])
        let message = try XCTUnwrap(Self.solanaSigningMessage.data(using: .utf8))

        let signature = try SolanaSigner.signMessage(mnemonic: vector.mnemonic, message: message)

        XCTAssertEqual(signature.derivationPath, UniversalWalletDerivationPaths.solanaDefault)
        XCTAssertEqual(signature.address, expected["address"] as? String)
        XCTAssertEqual(signature.publicKey.hexString, expected["publicKeyHex"] as? String)
        XCTAssertEqual(signature.signature.count, 64)
        assertHex(signature.signatureHex, byteLength: 64)
        XCTAssertFalse(signature.signatureBase58.isEmpty)
        XCTAssertTrue(try SolanaSigner.verifyMessage(publicKey: signature.publicKey, message: message, signature: signature.signature))
        XCTAssertFalse(try SolanaSigner.verifyMessage(
            publicKey: signature.publicKey,
            message: try XCTUnwrap("tampered".data(using: .utf8)),
            signature: signature.signature
        ))
    }

    func testSolanaSignerRejectsUnsafeInputs() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let message = try XCTUnwrap(Self.solanaSigningMessage.data(using: .utf8))

        XCTAssertThrowsError(try SolanaSigner.signMessage(privateKey: Data(repeating: 0, count: 31), message: message))
        XCTAssertThrowsError(try SolanaSigner.signMessage(mnemonic: vector.mnemonic, message: Data()))
        XCTAssertThrowsError(try SolanaSigner.signMessage(mnemonic: vector.mnemonic, message: Data(repeating: 0, count: 64 * 1024 + 1)))
        XCTAssertThrowsError(try SolanaSigner.verifyMessage(publicKey: Data(repeating: 0, count: 31), message: message, signature: Data(repeating: 0, count: 64)))
        XCTAssertThrowsError(try SolanaSigner.verifyMessage(publicKey: Data(repeating: 0, count: 32), message: message, signature: Data(repeating: 0, count: 63)))
    }

    func testTonKeyDerivationMatchesGoldenVectors() throws {
        for vector in try loadFixture().vectors {
            let expected = try XCTUnwrap(vector.expected["ton"] as? [String: Any])
            let account = try TonKeyDerivation.deriveAccount(mnemonic: vector.mnemonic)

            XCTAssertEqual(account.derivationPath, UniversalWalletDerivationPaths.tonDefault)
            XCTAssertEqual(account.derivationPath, expected["derivationPath"] as? String)
            XCTAssertEqual(account.publicKeyHex, expected["publicKeyHex"] as? String)
            XCTAssertEqual(account.addressBounceable, expected["addressBounceable"] as? String)
            XCTAssertEqual(account.addressNonBounceable, expected["addressNonBounceable"] as? String)
            XCTAssertEqual(account.testnetNonBounceable, expected["testnetNonBounceable"] as? String)
            XCTAssertEqual(account.privateKey.count, 32)
            XCTAssertEqual(account.chainCode.count, 32)
            XCTAssertEqual(account.publicKey.count, 32)
            XCTAssertEqual(account.accountHash.count, 32)
        }
    }

    func testTonKeyDerivationNormalizesMnemonicWhitespace() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["ton"] as? [String: Any])
        let paddedMnemonic = "  \(vector.mnemonic.replacingOccurrences(of: " ", with: "   \n\t"))  "

        let account = try TonKeyDerivation.deriveAccount(mnemonic: paddedMnemonic)

        XCTAssertEqual(account.publicKeyHex, expected["publicKeyHex"] as? String)
        XCTAssertEqual(account.addressNonBounceable, expected["addressNonBounceable"] as? String)
    }

    func testTonKeyDerivationDoesNotReuseVectorsAcrossPathsPassphrasesOrNetworkFlags() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let expected = try XCTUnwrap(vector.expected["ton"] as? [String: Any])
        let account = try TonKeyDerivation.deriveAccount(mnemonic: vector.mnemonic)
        let wrongPath = try TonKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            derivationPath: "m/44'/607'/1'/0'/0'"
        )
        let withPassphrase = try TonKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            passphrase: "fearless"
        )

        XCTAssertNotEqual(wrongPath.publicKeyHex, expected["publicKeyHex"] as? String)
        XCTAssertNotEqual(wrongPath.addressNonBounceable, expected["addressNonBounceable"] as? String)
        XCTAssertNotEqual(withPassphrase.publicKeyHex, expected["publicKeyHex"] as? String)
        XCTAssertNotEqual(withPassphrase.addressNonBounceable, expected["addressNonBounceable"] as? String)
        XCTAssertNotEqual(account.addressNonBounceable, account.testnetNonBounceable)
        XCTAssertEqual(
            try TonAddressCodec.friendlyAddress(accountHash: account.accountHash, isTestnet: false, bounceable: true),
            expected["addressBounceable"] as? String
        )
        XCTAssertEqual(
            try TonAddressCodec.friendlyAddress(accountHash: account.accountHash, isTestnet: true, bounceable: false),
            expected["testnetNonBounceable"] as? String
        )
    }

    func testTonKeyDerivationRejectsMalformedInputs() throws {
        let mnemonic = try XCTUnwrap(try loadFixture().vectors.first?.mnemonic)

        XCTAssertThrowsError(try TonKeyDerivation.deriveAccount(mnemonic: ""))
        XCTAssertThrowsError(try TonKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: ""))
        XCTAssertThrowsError(try TonKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: "44'/607'/0'/0'/0'"))
        XCTAssertThrowsError(try TonKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: "m/44'/607/0'/0'/0'"))
        XCTAssertThrowsError(try TonAddressCodec.v4R2Addresses(publicKey: Data(repeating: 0, count: 31)))
        XCTAssertThrowsError(try TonAddressCodec.friendlyAddress(accountHash: Data(repeating: 0, count: 31), isTestnet: false, bounceable: false))
    }

    func testIrohaKeyDerivationMatchesGoldenVectors() throws {
        for vector in try loadFixture().vectors {
            let iroha = try XCTUnwrap(vector.expected["iroha"] as? [String: Any])
            let taira = try XCTUnwrap(iroha["taira"] as? [String: Any])
            let nexus = try XCTUnwrap(iroha["nexus"] as? [String: Any])
            let account = try IrohaKeyDerivation.deriveAccount(mnemonic: vector.mnemonic)
            let tairaAddress = try IrohaKeyDerivation.deriveAddress(
                mnemonic: vector.mnemonic,
                chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            )
            let nexusAddress = try IrohaKeyDerivation.deriveAddress(
                mnemonic: vector.mnemonic,
                chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            )

            XCTAssertEqual(account.derivationPath, UniversalWalletDerivationPaths.irohaDefault)
            XCTAssertEqual(account.derivationPath, iroha["derivationPath"] as? String)
            XCTAssertEqual(account.publicKeyHex, taira["publicKeyHex"] as? String)
            XCTAssertEqual(account.canonicalHex, taira["canonicalHex"] as? String)
            XCTAssertEqual(tairaAddress.i105, taira["i105"] as? String)
            XCTAssertEqual(nexusAddress.i105, nexus["i105"] as? String)
            XCTAssertEqual(taira["publicKeyHex"] as? String, nexus["publicKeyHex"] as? String)
            XCTAssertEqual(taira["canonicalHex"] as? String, nexus["canonicalHex"] as? String)
        }
    }

    func testIrohaKeyDerivationDoesNotReuseVectorsAcrossPathsOrPassphrases() throws {
        let vector = try XCTUnwrap(try loadFixture().vectors.first)
        let iroha = try XCTUnwrap(vector.expected["iroha"] as? [String: Any])
        let taira = try XCTUnwrap(iroha["taira"] as? [String: Any])
        let wrongPath = try IrohaKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            derivationPath: "m/44'/617'/1'/0'"
        )
        let withPassphrase = try IrohaKeyDerivation.deriveAccount(
            mnemonic: vector.mnemonic,
            passphrase: "fearless"
        )

        XCTAssertNotEqual(wrongPath.publicKeyHex, taira["publicKeyHex"] as? String)
        XCTAssertNotEqual(wrongPath.canonicalHex, taira["canonicalHex"] as? String)
        XCTAssertNotEqual(withPassphrase.publicKeyHex, taira["publicKeyHex"] as? String)
        XCTAssertNotEqual(withPassphrase.canonicalHex, taira["canonicalHex"] as? String)
    }

    func testIrohaKeyDerivationRejectsMalformedInputs() throws {
        let mnemonic = try XCTUnwrap(try loadFixture().vectors.first?.mnemonic)

        XCTAssertThrowsError(try IrohaKeyDerivation.deriveAccount(mnemonic: ""))
        XCTAssertThrowsError(try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: ""))
        XCTAssertThrowsError(try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: "44'/617'/0'/0'"))
        XCTAssertThrowsError(try IrohaKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: "m/44'/617/0'/0'"))
        XCTAssertThrowsError(try IrohaKeyDerivation.deriveAddress(mnemonic: mnemonic, chainDiscriminant: -1))
    }

    private func loadFixture() throws -> UniversalWalletFixture {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent("docs/universal-wallet-v2-vectors.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(UniversalWalletFixture.self, from: data)
    }

    private func assertBitcoin(_ bitcoin: [String: Any]) throws {
        let mainnet = try XCTUnwrap(bitcoin["mainnet"] as? [String: Any])
        let testnet = try XCTUnwrap(bitcoin["testnet"] as? [String: Any])

        XCTAssertEqual(mainnet["accountPath"] as? String, "m/84'/0'/0'")
        XCTAssertEqual(mainnet["firstReceivePath"] as? String, "m/84'/0'/0'/0/0")
        XCTAssertTrue(try XCTUnwrap(mainnet["accountXpub"] as? String).hasPrefix("xpub"))
        XCTAssertTrue(try XCTUnwrap(mainnet["firstReceiveAddress"] as? String).hasPrefix("bc1q"))

        XCTAssertEqual(testnet["accountPath"] as? String, "m/84'/1'/0'")
        XCTAssertEqual(testnet["firstReceivePath"] as? String, "m/84'/1'/0'/0/0")
        XCTAssertTrue(try XCTUnwrap(testnet["accountXpub"] as? String).hasPrefix("xpub"))
        XCTAssertTrue(try XCTUnwrap(testnet["firstReceiveAddress"] as? String).hasPrefix("tb1q"))
    }

    private func assertSolana(_ solana: [String: Any]) throws {
        XCTAssertEqual(solana["derivationPath"] as? String, "m/44'/501'/0'/0'")
        assertHex(try XCTUnwrap(solana["publicKeyHex"] as? String), byteLength: 32)
        assertMatches(try XCTUnwrap(solana["address"] as? String), pattern: "^[1-9A-HJ-NP-Za-km-z]{32,44}$")
    }

    private func assertTon(_ ton: [String: Any]) throws {
        XCTAssertEqual(ton["derivationPath"] as? String, "m/44'/607'/0'/0'/0'")
        XCTAssertEqual(ton["walletVersion"] as? String, "v4r2")
        XCTAssertEqual(ton["workchain"] as? Int, 0)
        assertHex(try XCTUnwrap(ton["publicKeyHex"] as? String), byteLength: 32)
        XCTAssertTrue(try XCTUnwrap(ton["addressBounceable"] as? String).hasPrefix("EQ"))
        XCTAssertTrue(try XCTUnwrap(ton["addressNonBounceable"] as? String).hasPrefix("UQ"))
        XCTAssertTrue(try XCTUnwrap(ton["testnetNonBounceable"] as? String).hasPrefix("0Q"))
    }

    private func assertIroha(_ iroha: [String: Any]) throws {
        XCTAssertEqual(iroha["derivationPath"] as? String, "m/44'/617'/0'/0'")
        for network in ["taira", "nexus"] {
            let address = try XCTUnwrap(iroha[network] as? [String: Any])
            assertHex(try XCTUnwrap(address["publicKeyHex"] as? String), byteLength: 32)
            XCTAssertTrue(try XCTUnwrap(address["canonicalHex"] as? String).hasPrefix("0x02000120"))
            XCTAssertFalse(try XCTUnwrap(address["i105"] as? String).isEmpty)
        }
    }

    private func assertHex(_ value: String, byteLength: Int) {
        assertMatches(value, pattern: "^[0-9a-f]{\(byteLength * 2)}$")
    }

    private func assertMatches(_ value: String, pattern: String) {
        XCTAssertNotNil(value.range(of: pattern, options: .regularExpression))
    }

    private static let solanaSigningMessage = "Fearless Solana sign-in challenge"
}

private struct UniversalWalletFixture: Decodable {
    let version: Int
    let vectors: [UniversalWalletVector]
    let negativeCases: [UniversalWalletNegativeCase]
}

private struct UniversalWalletVector: Decodable {
    let id: String
    let mnemonic: String
    let wordCount: Int
    let expected: [String: Any]

    private enum CodingKeys: String, CodingKey {
        case id
        case mnemonic
        case wordCount
        case expected
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        mnemonic = try container.decode(String.self, forKey: .mnemonic)
        wordCount = try container.decode(Int.self, forKey: .wordCount)
        expected = try container.decodeJSONDictionary(forKey: .expected)
    }
}

private struct UniversalWalletNegativeCase: Decodable {
    let id: String
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension KeyedDecodingContainer {
    func decodeJSONDictionary(forKey key: Key) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: decodeRawJSONObject(forKey: key), options: [])
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    func decodeRawJSONObject(forKey key: Key) throws -> Any {
        let value = try decode(AnyDecodable.self, forKey: key)
        return value.value
    }
}

private struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var dictionary: [String: Any] = [:]
            for key in container.allKeys {
                dictionary[key.stringValue] = try container.decode(AnyDecodable.self, forKey: key).value
            }
            value = dictionary
        } else if var container = try? decoder.unkeyedContainer() {
            var array: [Any] = []
            while !container.isAtEnd {
                array.append(try container.decode(AnyDecodable.self).value)
            }
            value = array
        } else {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self.value = value
            } else if let value = try? container.decode(Int.self) {
                self.value = value
            } else if let value = try? container.decode(Bool.self) {
                self.value = value
            } else if container.decodeNil() {
                value = NSNull()
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
            }
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
