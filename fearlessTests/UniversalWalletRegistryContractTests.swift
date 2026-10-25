import XCTest
@testable import fearless

final class UniversalWalletRegistryContractTests: XCTestCase {
    func testValidatesAndSerializesPublicChainRegistryEntries() throws {
        let registry = UniversalWalletChainRegistry(chains: [solanaMainnet(), taira()])

        XCTAssertTrue(registry.validationErrors().isEmpty)

        let json = String(decoding: try JSONEncoder().encode(registry), as: UTF8.self)
        XCTAssertTrue(json.contains(#""ecosystem":"solana""#))
        XCTAssertTrue(json.contains(#""kind":"indexer""#))
        XCTAssertTrue(json.contains(#""kind":"torii-mcp""#))
        XCTAssertTrue(json.contains(#""readOnly":true"#))
        XCTAssertTrue(json.contains(#""features":["transfer"]"#))
    }

    func testAllowsDisabledGatedNetworksWithoutEndpoints() {
        let nexus = UniversalWalletChainRegistryEntry(
            id: "sora-nexus-mainnet",
            ecosystem: .iroha,
            chainId: "sora:nexus:global",
            displayName: "SORA Nexus",
            enabledByDefault: false,
            features: ["transfer", "offline-cash", "sccp", "governance"],
            endpoints: []
        )

        XCTAssertTrue(nexus.validationErrors().isEmpty)
    }

    func testActualDefaultRegistryEntriesValidateAndExposeExpectedPublicEndpoints() throws {
        let registry = UniversalWalletRegistry.chainRegistry

        XCTAssertTrue(registry.validationErrors().isEmpty)
        let ids = Set(registry.chains.map(\.id))
        XCTAssertTrue(
            [
                "bitcoin-mainnet",
                "bitcoin-testnet",
                "ton-mainnet",
                "solana-mainnet",
                "solana-devnet",
                "taira-testnet",
                "sora-nexus-mainnet"
            ].allSatisfy(ids.contains)
        )

        let bitcoinMainnet = try XCTUnwrap(registry.chains.first { $0.id == "bitcoin-mainnet" })
        XCTAssertTrue(bitcoinMainnet.enabledByDefault)
        XCTAssertEqual(bitcoinMainnet.features, ["transfer"])
        XCTAssertEqual(bitcoinMainnet.endpoints.count, 1)
        XCTAssertTrue(
            bitcoinMainnet.endpoints.contains {
                $0.kind == .indexer &&
                    $0.url == UniversalWalletRegistry.bitcoinMainnetIndexerBaseURL.absoluteString &&
                    $0.readOnly
            }
        )

        let bitcoinTestnet = try XCTUnwrap(registry.chains.first { $0.id == "bitcoin-testnet" })
        XCTAssertFalse(bitcoinTestnet.enabledByDefault)
        XCTAssertEqual(bitcoinTestnet.endpoints.count, 1)
        XCTAssertTrue(
            bitcoinTestnet.endpoints.contains {
                $0.kind == .indexer &&
                    $0.url == UniversalWalletRegistry.bitcoinTestnetIndexerBaseURL.absoluteString &&
                    $0.readOnly
            }
        )

        let solana = try XCTUnwrap(registry.chains.first { $0.id == "solana-mainnet" })
        XCTAssertTrue(
            solana.endpoints.contains {
                $0.kind == .indexer &&
                    $0.url == "https://si.soramitsu.io" &&
                    $0.readOnly
            }
        )
        XCTAssertTrue(
            solana.endpoints.contains {
                $0.kind == .rpc &&
                    $0.url == "https://api.mainnet-beta.solana.com" &&
                    !$0.readOnly
            }
        )

        let ton = try XCTUnwrap(registry.chains.first { $0.id == "ton-mainnet" })
        XCTAssertTrue(
            ton.endpoints.contains {
                $0.kind == .indexer &&
                    $0.url == "https://ti.soramitsu.io" &&
                    $0.readOnly
            }
        )

        let taira = try XCTUnwrap(registry.chains.first { $0.id == "taira-testnet" })
        XCTAssertEqual(taira.features, ["receive"])
        XCTAssertEqual(taira.nativeAsset?.id, "6TEAJqbb8oEPmLncoNiMRbLEK6tw")
        XCTAssertEqual(taira.nativeAsset?.symbol, "XOR")
        XCTAssertEqual(taira.nativeAsset?.decimals, 28)
        XCTAssertTrue(
            taira.endpoints.contains {
                $0.kind == .toriiMcp &&
                    $0.url == "https://taira.sora.org/v1/mcp" &&
                    !$0.readOnly
            }
        )

        let nexus = try XCTUnwrap(registry.chains.first { $0.id == "sora-nexus-mainnet" })
        XCTAssertFalse(nexus.enabledByDefault)
        XCTAssertEqual(nexus.features, ["transfer", "offline-cash", "sccp", "governance"])
        XCTAssertTrue(
            nexus.endpoints.contains {
                $0.kind == .toriiMcp &&
                    $0.url == "https://minamoto.sora.org/v1/mcp" &&
                    !$0.readOnly
            }
        )
    }

    func testRejectsMalformedRegistryEntriesAndPublicWriteIndexers() {
        let chain = UniversalWalletChainRegistryEntry(
            id: "../bad",
            ecosystem: "unknown",
            chainId: "bad chain",
            displayName: "bad\u{0000}name",
            enabledByDefault: true,
            nativeAsset: UniversalWalletRegistryAsset(
                id: "bad id",
                symbol: "sol",
                decimals: 256,
                name: "bad\u{0000}name"
            ),
            derivationPath: "m/44'/x",
            slip44CoinType: -1,
            features: ["governance", "governance", "bad feature"],
            endpoints: [
                UniversalWalletRegistryEndpoint(
                    id: "bad endpoint",
                    kind: .indexer,
                    url: "http://si.soramitsu.io",
                    readOnly: false,
                    priority: -1
                )
            ]
        )

        let errors = chain.validationErrors()

        XCTAssertTrue(errors.contains(.invalidId))
        XCTAssertTrue(errors.contains(.invalidEcosystem))
        XCTAssertTrue(errors.contains(.invalidChainId))
        XCTAssertTrue(errors.contains(.invalidDisplayName))
        XCTAssertTrue(errors.contains(.invalidAssetId))
        XCTAssertTrue(errors.contains(.invalidAssetSymbol))
        XCTAssertTrue(errors.contains(.invalidAssetDecimals))
        XCTAssertTrue(errors.contains(.invalidAssetName))
        XCTAssertTrue(errors.contains(.invalidDerivationPath))
        XCTAssertTrue(errors.contains(.invalidSlip44CoinType))
        XCTAssertTrue(errors.contains(.duplicateFeatureId))
        XCTAssertTrue(errors.contains(.invalidFeatureId))
        XCTAssertTrue(errors.contains(.invalidEndpointId))
        XCTAssertTrue(errors.contains(.invalidEndpointUrl))
        XCTAssertTrue(errors.contains(.invalidEndpointPriority))
        XCTAssertTrue(errors.contains(.publicWriteIndexer))
    }

    func testRejectsDuplicateChainAndEndpointIdentifiers() {
        let duplicateEndpoint = UniversalWalletChainRegistryEntry(
            id: "solana-mainnet",
            ecosystem: .solana,
            chainId: "solana:mainnet",
            displayName: "Solana",
            enabledByDefault: true,
            endpoints: [indexer(), indexer()]
        )
        let registry = UniversalWalletChainRegistry(
            schemaVersion: 99,
            chains: [solanaMainnet(), solanaMainnet(), duplicateEndpoint]
        )

        let errors = registry.validationErrors()

        XCTAssertTrue(errors.contains(.invalidSchemaVersion))
        XCTAssertTrue(errors.contains(.duplicateChainId))
        XCTAssertTrue(errors.contains(.duplicateEndpointId))
    }

    private func solanaMainnet() -> UniversalWalletChainRegistryEntry {
        UniversalWalletChainRegistryEntry(
            id: "solana-mainnet",
            ecosystem: .solana,
            chainId: "solana:mainnet",
            displayName: "Solana",
            enabledByDefault: true,
            nativeAsset: UniversalWalletRegistryAsset(
                id: "SOL",
                symbol: "SOL",
                decimals: 9,
                name: "Solana"
            ),
            derivationPath: "m/44'/501'/0'/0'",
            slip44CoinType: 501,
            endpoints: [
                indexer(),
                UniversalWalletRegistryEndpoint(
                    id: "solana-mainnet-rpc",
                    kind: .rpc,
                    url: "https://api.mainnet-beta.solana.com",
                    readOnly: false,
                    priority: 1
                )
            ]
        )
    }

    private func taira() -> UniversalWalletChainRegistryEntry {
        UniversalWalletChainRegistryEntry(
            id: "taira-testnet",
            ecosystem: .iroha,
            chainId: "iroha3-taira",
            displayName: "Taira Testnet",
            enabledByDefault: true,
            features: ["transfer"],
            endpoints: [
                UniversalWalletRegistryEndpoint(
                    id: "taira-torii-mcp",
                    kind: .toriiMcp,
                    url: "https://taira.sora.org/v1/mcp",
                    readOnly: false
                )
            ]
        )
    }

    private func indexer() -> UniversalWalletRegistryEndpoint {
        UniversalWalletRegistryEndpoint(
            id: "solana-mainnet-indexer",
            kind: .indexer,
            url: "https://si.soramitsu.io",
            readOnly: true
        )
    }
}
