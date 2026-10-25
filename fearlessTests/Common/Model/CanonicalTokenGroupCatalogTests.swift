import BigInt
import CryptoKit
import XCTest
@testable import fearless
import SSFModels

/// App-owned portfolio catalogs resolve registry assets to reviewed token groups.
/// The frozen registry fixture retains the reviewed membership and receiving identities.
final class CanonicalTokenGroupCatalogTests: XCTestCase {
    // Byte commitments for the app-owned catalogs. The ownership migration changed only
    // registry.source; approved membership, registry snapshot and receiving identities are unchanged.
    private static let CANONICAL_ASSET_GROUPS_SHA256 = "8caafa5c20915c8949b1b74145763621d8c4149459466633d9a697bf83e06d08"
    private static let TESTNET_CHAIN_IDS_SHA256 = "f45ac84298427552a7e6d8991a3b07a677fedd4b062127e3190cd2291175ac47"
    private static let DEFAULT_VISIBLE_AT_ZERO_SHA256 = "dded1e9a4e0b492004f09c74cc92fd0cfdae7f12197deb5add84462942c45116"

    /// Byte copy of the root `config/portfolio/parity-cases.v1.json` in the test bundle's `Registry/`.
    private static let parityCasesSha256 = "aab5746a3bf2aa75d661266c75ebea37138cde8aacd426e08508c06d2e5daa81"
    private static let registrySnapshotSha256 = "fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66"

    private static let approvedGroups: [String: Int] = [
        "dot": 12, "ksm": 16, "eth": 4, "usdt": 3, "usdc": 6, "btc": 1
    ]

    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var cachedRegistryChains: [ChainModel]?

    override func setUp() {
        super.setUp()
        suiteName = "CanonicalTokenGroupCatalogTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        cachedRegistryChains = nil
        ExactAssetPriceCache.shared.clear()
        super.tearDown()
    }

    // MARK: - Bundled copies

    func testBundledFilesSha256MatchPinnedValues() throws {
        let pins = [
            CanonicalTokenGroupCatalog.resourceName: Self.CANONICAL_ASSET_GROUPS_SHA256,
            PortfolioTestnetChainList.resourceName: Self.TESTNET_CHAIN_IDS_SHA256,
            PortfolioZeroDefaultList.resourceName: Self.DEFAULT_VISIBLE_AT_ZERO_SHA256
        ]

        for (name, pinned) in pins {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json"), name)
            XCTAssertEqual(sha256(try Data(contentsOf: url)), pinned, "\(name).json drifted from the reviewed app-owned bytes")
        }
    }

    func testBundledCatalogLoadsOnlyApprovedGroups() {
        let catalog = CanonicalTokenGroupCatalog.bundled

        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: catalog.groups.map { ($0.id, $0.members.count) }),
            Self.approvedGroups
        )
        XCTAssertEqual(catalog.groups.first { $0.id == "dot" }?.priceId, "polkadot")
        XCTAssertTrue(catalog.testnets.isLoaded)
        XCTAssertTrue(PortfolioZeroDefaultList.bundled.isLoaded)
    }

    func testBundledFileStillListsProposedGroupsThatNeverLoad() throws {
        let object = try JSONSerialization.jsonObject(with: try bundledData(CanonicalTokenGroupCatalog.resourceName))
        let groups = try XCTUnwrap((object as? [String: Any])?["groups"] as? [[String: Any]])
        let proposed = groups.filter { $0["status"] as? String == "proposed" }.compactMap { $0["id"] as? String }

        XCTAssertTrue(proposed.contains("weth-ethereum"))
        XCTAssertTrue(proposed.contains("usdc-e-ethereum"))
        XCTAssertTrue(Set(proposed).isDisjoint(with: CanonicalTokenGroupCatalog.bundled.groups.map(\.id)))
    }

    // MARK: - Resolution against the reviewed registry snapshot (critique T-5a)

    func testEveryApprovedMemberResolvesAndNothingElseDoes() throws {
        let catalog = try bundledCatalog()
        let chainAssets = try registryChainAssets()

        var resolved: [String: Set<String>] = [:]
        for chainAsset in chainAssets {
            if let group = catalog.group(for: chainAsset) {
                resolved[group.id, default: []].insert(memberKey(chainAsset.chain.chainId, chainAsset.asset.id))
            }
        }

        let listed = Dictionary(uniqueKeysWithValues: catalog.groups.map { group in
            (group.id, Set(group.members.map { memberKey($0.chainId, $0.assetId) }))
        })
        XCTAssertEqual(resolved, listed)
        XCTAssertEqual(resolved.mapValues(\.count), Self.approvedGroups)
    }

    func testNoAssetBelongsToTwoGroupsInTheBundledFile() throws {
        let object = try JSONSerialization.jsonObject(with: try bundledData(CanonicalTokenGroupCatalog.resourceName))
        let groups = try XCTUnwrap((object as? [String: Any])?["groups"] as? [[String: Any]])

        var seen = Set<String>()
        for group in groups {
            for member in try XCTUnwrap(group["members"] as? [[String: Any]]) {
                let key = memberKey(
                    try XCTUnwrap(member["chainId"] as? String),
                    try XCTUnwrap(member["assetId"] as? String).lowercased()
                )
                XCTAssertTrue(seen.insert(key).inserted, "\(key) is listed twice")
            }
        }
    }

    func testNoMemberIsOnATestnetOrDisabledNetwork() throws {
        let catalog = try bundledCatalog()
        let members = try registryChainAssets().filter { catalog.group(for: $0) != nil }

        XCTAssertFalse(members.isEmpty)
        for chainAsset in members {
            XCTAssertFalse(catalog.testnets.isTestnet(chainAsset.chain), chainAsset.chain.name)
            XCTAssertFalse(chainAsset.chain.disabled, chainAsset.chain.name)
        }
    }

    func testMemberSymbolsMatchGroupSymbolAfterXcStrip() throws {
        let catalog = try bundledCatalog()

        for chainAsset in try registryChainAssets() {
            guard let group = catalog.group(for: chainAsset) else {
                continue
            }
            var symbol = chainAsset.asset.symbol.lowercased()
            if symbol.hasPrefix("xc") {
                symbol.removeFirst(2)
            }
            XCTAssertEqual(symbol, group.symbol.lowercased(), "\(chainAsset.asset.symbol) on \(chainAsset.chain.name)")
        }
    }

    func testMemberPriceIdsAndPrecisionsAgreeWithinEachGroup() throws {
        let catalog = try bundledCatalog()
        var precisions: [String: Set<UInt16>] = [:]

        for chainAsset in try registryChainAssets() {
            guard let group = catalog.group(for: chainAsset) else {
                continue
            }
            XCTAssertEqual(chainAsset.asset.coingeckoPriceId, group.priceId, chainAsset.chain.name)
            precisions[group.id, default: []].insert(chainAsset.asset.precision)
        }

        XCTAssertTrue(precisions.values.allSatisfy { $0.count == 1 }, "\(precisions)")
    }

    func testNoMemberSharesItsAssetKeyWithAnotherRegistryAsset() throws {
        // Balances and visibility are keyed by AssetKey (currencyId before id), so a member must
        // not share that key with any other asset of its network.
        let catalog = try bundledCatalog()
        let chainAssets = try registryChainAssets()
        let keyCounts = chainAssets.reduce(into: [AssetKey: Int]()) { $0[$1.assetKey, default: 0] += 1 }

        for chainAsset in chainAssets where catalog.group(for: chainAsset) != nil {
            XCTAssertEqual(keyCounts[chainAsset.assetKey], 1, "\(chainAsset.asset.symbol) on \(chainAsset.chain.name)")
        }
    }

    func testDerivativesAndBridgedLookalikesAreNeverMembers() throws {
        let catalog = try bundledCatalog()
        let chainAssets = try registryChainAssets()

        func assertUngrouped(_ symbol: String, on network: String, file: StaticString = #filePath, line: UInt = #line) {
            let matches = chainAssets.filter { $0.chain.name == network && $0.asset.symbol.lowercased() == symbol }
            XCTAssertFalse(matches.isEmpty, "\(symbol) on \(network) missing from the snapshot", file: file, line: line)
            for chainAsset in matches {
                XCTAssertNil(catalog.group(for: chainAsset), "\(symbol) on \(network)", file: file, line: line)
            }
        }

        // Liquid-staking derivatives share priceId "kusama" with KSM.
        assertUngrouped("vksm", on: "Bifrost")
        assertUngrouped("vsksm", on: "Bifrost")
        assertUngrouped("vsksm", on: "Karura")
        // Wrapped and bridged ETH share priceId "ethereum" or the symbol with native ETH.
        assertUngrouped("weth", on: "Ethereum")
        assertUngrouped("weth", on: "Acala")
        assertUngrouped("eth", on: "BNB Smart Chain")
        assertUngrouped("eth", on: "SORA Mainnet")
        // SORA-bridged DOT and KSM use 18 decimals.
        assertUngrouped("dot", on: "SORA Mainnet")
        assertUngrouped("ksm", on: "SORA Mainnet")
        // Bridged stablecoins stay separate rows labelled with their network.
        assertUngrouped("usdc.e", on: "Polygon")
        assertUngrouped("usdc.e", on: "Arbitrum One")
        assertUngrouped("dai.e", on: "Avalanche C-Chain")
        assertUngrouped("usdc", on: "BNB Smart Chain")
        assertUngrouped("usdt", on: "Kusama AssetHub")
        assertUngrouped("xcusdt", on: "Moonbeam")
        // One contract address, two unrelated networks.
        assertUngrouped("usdt", on: "Polygon zkEVM")
        assertUngrouped("usdt", on: "X Layer Mainnet")
        // Wrapped BTC is not Bitcoin.
        assertUngrouped("wbtc", on: "Polygon")
    }

    func testAppOwnedBitcoinResolvesToItsSingleMemberGroup() throws {
        let catalog = try bundledCatalog()
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let bitcoin = try XCTUnwrap(chain.chainAssets.first)

        XCTAssertEqual(catalog.group(for: bitcoin)?.id, "btc")
        XCTAssertEqual(catalog.members(of: try XCTUnwrap(catalog.group(for: bitcoin)), among: [bitcoin]), [bitcoin])
    }

    // MARK: - Runtime safety checks

    func testUnverifiedAssetNeverResolvesToGroup() throws {
        let catalog = try bundledCatalog()
        let usdt = try registryChainAsset(symbol: "usdt", network: "Ethereum")
        XCTAssertEqual(catalog.group(for: usdt)?.id, "usdt")

        AssetTrustResolver.markUnverified(usdt, userDefaults: userDefaults)
        XCTAssertNil(catalog.group(for: usdt))

        // Indexer-verified metadata is still not registry metadata.
        AssetTrustResolver.markVerifiedFromIndexer(usdt, userDefaults: userDefaults)
        XCTAssertNil(catalog.group(for: usdt))

        AssetTrustResolver.markMissing(usdt, userDefaults: userDefaults)
        XCTAssertNil(catalog.group(for: usdt))
    }

    func testEvmAssetIdMatchingIsCaseInsensitive_substrateIsNot() throws {
        let catalog = try bundledCatalog()
        let usdc = try registryChainAsset(symbol: "usdc", network: "Ethereum")
        let dot = try registryChainAsset(symbol: "dot", network: "Polkadot")

        XCTAssertEqual(catalog.group(for: replacing(usdc, assetId: usdc.asset.id.lowercased()))?.id, "usdc")
        XCTAssertEqual(catalog.group(for: replacing(usdc, assetId: usdc.asset.id.uppercased()))?.id, "usdc")
        XCTAssertEqual(catalog.group(for: dot)?.id, "dot")
        XCTAssertNil(catalog.group(for: replacing(dot, assetId: dot.asset.id.uppercased())))
    }

    func testRegistryDriftMakesTheMemberInactive() throws {
        let catalog = try bundledCatalog()
        let dot = try registryChainAsset(symbol: "dot", network: "Polkadot")

        XCTAssertNil(catalog.group(for: replacing(dot, precision: 18)))
        XCTAssertNil(catalog.group(for: replacing(dot, symbol: "vdot")))
        XCTAssertNil(catalog.group(for: replacing(dot, priceId: "voucher-dot")))
        XCTAssertNil(catalog.group(for: replacing(dot, priceId: .some(nil))))
        // A symbol casing change is not a different asset.
        XCTAssertEqual(catalog.group(for: replacing(dot, symbol: "DOT"))?.id, "dot")
    }

    func testTestnetOrDisabledNetworkMakesTheMemberInactive() throws {
        let dot = try registryChainAsset(symbol: "dot", network: "Polkadot")
        let catalog = try bundledCatalog()

        XCTAssertNil(catalog.group(for: replacing(dot, chainOptions: [.testnet])))
        XCTAssertNil(catalog.group(for: replacing(dot, disabled: true)))

        let listedAsTestnet = CanonicalTokenGroupCatalog(
            data: try bundledData(CanonicalTokenGroupCatalog.resourceName),
            testnets: PortfolioTestnetChainList(chainIds: [dot.chain.chainId.uppercased()]),
            userDefaults: userDefaults
        )
        XCTAssertNil(listedAsTestnet.group(for: dot))
    }

    func testMembersOfGroupAndSameGroup() throws {
        let catalog = try bundledCatalog()
        let chainAssets = try registryChainAssets()
        let dotOnPolkadot = try registryChainAsset(symbol: "dot", network: "Polkadot")
        let dotOnAssetHub = try registryChainAsset(symbol: "dot", network: "Polkadot AssetHub")
        let xcDotOnMoonbeam = try registryChainAsset(symbol: "xcdot", network: "Moonbeam")
        let dotOnSora = try registryChainAsset(symbol: "dot", network: "SORA Mainnet")
        let ksm = try registryChainAsset(symbol: "ksm", network: "Kusama")
        let dot = try XCTUnwrap(catalog.group(for: dotOnPolkadot))

        let members = catalog.members(of: dot, among: chainAssets.reversed() + chainAssets)
        XCTAssertEqual(members.map(\.chain.chainId), dot.members.map(\.chainId))
        XCTAssertEqual(members.first, dotOnPolkadot)
        XCTAssertFalse(members.contains(dotOnSora))

        XCTAssertTrue(catalog.isSameGroup(dotOnPolkadot, dotOnAssetHub))
        XCTAssertTrue(catalog.isSameGroup(dotOnPolkadot, xcDotOnMoonbeam))
        XCTAssertFalse(catalog.isSameGroup(dotOnPolkadot, dotOnSora))
        XCTAssertFalse(catalog.isSameGroup(dotOnPolkadot, ksm))
        XCTAssertFalse(catalog.isSameGroup(dotOnSora, dotOnSora), "ungrouped assets have no group")
    }

    // MARK: - File validation (fail safe = no grouping)

    func testInvalidResourceYieldsEmptyCatalog() throws {
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let invalidDocuments: [Data?] = [
            nil,
            Data(),
            Data("not json".utf8),
            Data("[]".utf8),
            try mutated(valid) { $0["format"] = "fearless.token-groups" },
            try mutated(valid) { $0["version"] = 2 },
            try mutated(valid) { $0.removeValue(forKey: "groups") },
            try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                groups[0]["id"] = "DOT"
                document["groups"] = groups
            },
            try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                groups[1]["id"] = groups[0]["id"]
                document["groups"] = groups
            },
            try mutated(valid) { document in
                let groups = document["groups"] as? [[String: Any]] ?? []
                let copies = CanonicalTokenGroupCatalog.maxGroups / max(groups.count, 1) + 1
                document["groups"] = Array(repeating: groups, count: copies).flatMap { $0 }.enumerated().map { index, group in
                    var group = group
                    group["id"] = "group-\(index)"
                    return group
                }
            },
            try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                var members = groups[0]["members"] as? [[String: Any]] ?? []
                members[0].removeValue(forKey: "precision")
                groups[0]["members"] = members
                document["groups"] = groups
            }
        ]

        let dot = try registryChainAsset(symbol: "dot", network: "Polkadot")
        for (index, data) in invalidDocuments.enumerated() {
            let catalog = CanonicalTokenGroupCatalog(
                data: data,
                testnets: PortfolioTestnetChainList(chainIds: []),
                userDefaults: userDefaults
            )
            XCTAssertTrue(catalog.groups.isEmpty, "document \(index)")
            XCTAssertNil(catalog.group(for: dot), "document \(index)")
        }
    }

    func testDuplicateMemberInvalidatesEveryGroupContainingIt() throws {
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let catalog = CanonicalTokenGroupCatalog(
            data: try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                let dotIndex = try XCTUnwrap(groups.firstIndex { $0["id"] as? String == "dot" })
                let ksmIndex = try XCTUnwrap(groups.firstIndex { $0["id"] as? String == "ksm" })
                var ksmMembers = groups[ksmIndex]["members"] as? [[String: Any]] ?? []
                // DOT on Polkadot, listed again under KSM with an EVM-style casing change.
                var duplicate = try XCTUnwrap((groups[dotIndex]["members"] as? [[String: Any]])?.first)
                duplicate["assetId"] = (duplicate["assetId"] as? String)?.uppercased()
                ksmMembers.append(duplicate)
                groups[ksmIndex]["members"] = ksmMembers
                document["groups"] = groups
            },
            testnets: PortfolioTestnetChainList(chainIds: []),
            userDefaults: userDefaults
        )

        XCTAssertEqual(Set(catalog.groups.map(\.id)), ["eth", "usdt", "usdc", "btc"])
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "dot", network: "Polkadot AssetHub")))
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "ksm", network: "Kusama")))
        XCTAssertEqual(catalog.group(for: try registryChainAsset(symbol: "eth", network: "Ethereum"))?.id, "eth")
    }

    func testDuplicateWithAProposedGroupAlsoInvalidatesTheApprovedGroup() throws {
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let catalog = CanonicalTokenGroupCatalog(
            data: try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                let ethIndex = try XCTUnwrap(groups.firstIndex { $0["id"] as? String == "eth" })
                let wethIndex = try XCTUnwrap(groups.firstIndex { $0["id"] as? String == "weth-ethereum" })
                var wethMembers = groups[wethIndex]["members"] as? [[String: Any]] ?? []
                wethMembers.append(try XCTUnwrap((groups[ethIndex]["members"] as? [[String: Any]])?.first))
                groups[wethIndex]["members"] = wethMembers
                document["groups"] = groups
            },
            testnets: PortfolioTestnetChainList(chainIds: []),
            userDefaults: userDefaults
        )

        XCTAssertFalse(catalog.groups.contains { $0.id == "eth" })
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "eth", network: "Arbitrum One")))
    }

    func testProposedStatusUnknownKindAndUnreviewedSymbolNeverResolve() throws {
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let catalog = CanonicalTokenGroupCatalog(
            data: try mutated(valid) { document in
                var groups = document["groups"] as? [[String: Any]] ?? []
                for index in groups.indices {
                    var members = groups[index]["members"] as? [[String: Any]] ?? []
                    switch groups[index]["id"] as? String {
                    case "dot":
                        groups[index]["status"] = "proposed"
                    case "ksm":
                        groups[index]["status"] = "candidate"
                    case "usdc":
                        // A member kind this build does not know is skipped, not guessed.
                        members[0]["kind"] = "solanaMint"
                    case "eth":
                        // Without its reviewed alias a symbol never matches the group.
                        groups[index]["symbol"] = "ETHER"
                    default:
                        break
                    }
                    groups[index]["members"] = members
                }
                document["groups"] = groups
            },
            testnets: PortfolioTestnetChainList(chainIds: []),
            userDefaults: userDefaults
        )

        XCTAssertEqual(Set(catalog.groups.map(\.id)), ["usdt", "usdc", "btc"])
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "dot", network: "Polkadot")))
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "ksm", network: "Kusama")))
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "usdc", network: "Ethereum")))
        XCTAssertEqual(catalog.group(for: try registryChainAsset(symbol: "usdc", network: "Arbitrum One"))?.id, "usdc")
        XCTAssertNil(catalog.group(for: try registryChainAsset(symbol: "eth", network: "Ethereum")))
    }

    // MARK: - Untrusted prices (contract §3 and §10)

    func testBundledUntrustedPriceListNamesExactlyItsRegistryAssets() throws {
        let list = PortfolioUntrustedPriceList.bundled
        let chainAssets = try registryChainAssets()

        XCTAssertFalse(list.entries.isEmpty)
        XCTAssertEqual(try bundledCatalog().untrustedPrices.entries, list.entries)
        for entry in list.entries {
            let matches = chainAssets.filter { $0.chain.chainId == entry.chainId && $0.asset.id == entry.assetId }
            XCTAssertEqual(matches.count, 1, "\(entry.chainId) \(entry.assetId)")
            XCTAssertTrue(matches.allSatisfy(list.contains))
            // The registry still prices it, which is why the list exists.
            XCTAssertNotNil(matches.first?.asset.priceId, entry.assetId)
        }
        XCTAssertEqual(chainAssets.filter(list.contains).count, list.entries.count, "nothing else is distrusted")

        // The third-party Kusama AssetHub "USDT" (Assets id 11), not Tether's own deployments.
        XCTAssertTrue(list.contains(try registryChainAsset(symbol: "usdt", network: "Kusama AssetHub")))
        XCTAssertFalse(list.contains(try registryChainAsset(symbol: "usdt", network: "Polkadot AssetHub")))
        XCTAssertFalse(list.contains(try registryChainAsset(symbol: "ksm", network: "Kusama AssetHub")))
    }

    func testUntrustedAssetIsNeverGroupedEvenIfAGroupListsIt() throws {
        let untrusted = try registryChainAsset(symbol: "usdt", network: "Kusama AssetHub")
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let addingMember: (inout [String: Any]) throws -> Void = { document in
            var groups = document["groups"] as? [[String: Any]] ?? []
            let index = try XCTUnwrap(groups.firstIndex { $0["id"] as? String == "usdt" })
            var members = groups[index]["members"] as? [[String: Any]] ?? []
            members.append([
                "chainId": untrusted.chain.chainId,
                "assetId": untrusted.asset.id,
                "symbol": untrusted.asset.symbol,
                "precision": Int(untrusted.asset.precision)
            ])
            groups[index]["members"] = members
            document["groups"] = groups
        }
        let catalog = { (data: Data) in
            CanonicalTokenGroupCatalog(data: data, testnets: .bundled, userDefaults: self.userDefaults)
        }

        let listed = catalog(try mutated(valid, addingMember))
        XCTAssertNil(listed.group(for: untrusted))
        XCTAssertFalse(listed.isSameGroup(untrusted, try registryChainAsset(symbol: "usdt", network: "Ethereum")))

        // Without the list the same file would group it with Tether, so the list is what keeps it out.
        let unlisted = catalog(try mutated(valid) { document in
            try addingMember(&document)
            document.removeValue(forKey: "untrustedAssets")
        })
        XCTAssertTrue(unlisted.untrustedPrices.entries.isEmpty)
        XCTAssertEqual(unlisted.group(for: untrusted)?.id, "usdt")
    }

    func testUntrustedPriceListIsReadWithoutTheGroups() throws {
        let valid = try bundledJSON(CanonicalTokenGroupCatalog.resourceName)
        let untrusted = try registryChainAsset(symbol: "usdt", network: "Kusama AssetHub")

        // Unusable for grouping (two groups share an id), yet the prices stay withheld.
        let duplicateGroupIds = try mutated(valid) { document in
            var groups = document["groups"] as? [[String: Any]] ?? []
            groups[1]["id"] = groups[0]["id"]
            document["groups"] = groups
        }
        let catalog = CanonicalTokenGroupCatalog(data: duplicateGroupIds, testnets: .bundled, userDefaults: userDefaults)
        XCTAssertTrue(catalog.groups.isEmpty)
        XCTAssertTrue(catalog.untrustedPrices.contains(untrusted))
        XCTAssertTrue(PortfolioUntrustedPriceList(data: try mutated(valid) { $0.removeValue(forKey: "groups") }).contains(untrusted))

        let unreadable: [Data?] = [
            nil,
            Data("not json".utf8),
            try mutated(valid) { $0["format"] = "fearless.token-groups" },
            try mutated(valid) { $0["version"] = 2 },
            try mutated(valid) { $0.removeValue(forKey: "untrustedAssets") },
            try mutated(valid) { $0["untrustedAssets"] = [["chainId": untrusted.chain.chainId]] }
        ]
        for (index, data) in unreadable.enumerated() {
            XCTAssertTrue(PortfolioUntrustedPriceList(data: data).entries.isEmpty, "document \(index)")
        }
    }

    func testUntrustedAssetIdsCompareExactlyExceptOnEvmNetworks() throws {
        let substrate = try registryChainAsset(symbol: "usdt", network: "Kusama AssetHub")
        let substrateList = PortfolioUntrustedPriceList(entries: [
            .init(chainId: substrate.chain.chainId.uppercased(), assetId: substrate.asset.id)
        ])
        XCTAssertTrue(substrateList.contains(substrate), "chain ids compare lowercased")
        XCTAssertFalse(substrateList.contains(replacing(substrate, assetId: substrate.asset.id.uppercased())))
        XCTAssertFalse(substrateList.contains(try registryChainAsset(symbol: "ksm", network: "Kusama AssetHub")))

        let evm = try registryChainAsset(symbol: "usdt", network: "Ethereum")
        let evmList = PortfolioUntrustedPriceList(entries: [
            .init(chainId: evm.chain.chainId, assetId: evm.asset.id.uppercased())
        ])
        XCTAssertTrue(evmList.contains(evm))
    }

    /// Contract §10: every `untrustedAssets` entry, given a balance and its registry price, adds no
    /// fiat to the header total, the network subtotal or its row, and counts as having no price.
    func testUntrustedAssetsWithABalanceAndARegistryPriceAddNoFiat() throws {
        let usd = Currency.defaultCurrency()
        let wallet = AccountGenerator.generateMetaAccount()
        let control = try registryChainAsset(symbol: "usdt", network: "Polkadot AssetHub")
        let controlPriceId = try XCTUnwrap(control.asset.priceId)
        let chainAssets = try registryChainAssets()

        for entry in PortfolioUntrustedPriceList.bundled.entries {
            let untrusted = try XCTUnwrap(chainAssets.first {
                $0.chain.chainId == entry.chainId && $0.asset.id == entry.assetId
            })
            let priceId = try XCTUnwrap(untrusted.asset.priceId)
            ExactAssetPriceCache.shared.upsert(Set([priceId, controlPriceId]).map {
                PriceData(currencyId: usd.id, priceId: $0, price: "1", fiatDayChange: nil, coingeckoPriceId: $0)
            })
            // 1,000,000 whole tokens of the untrusted asset, 5 USDT of the control.
            let accountInfos = try balances(wallet: wallet, values: [
                untrusted: BigUInt(1_000_000) * BigUInt(10).power(Int(untrusted.asset.precision)),
                control: BigUInt(5) * BigUInt(10).power(Int(control.asset.precision))
            ])

            XCTAssertNotNil(untrusted.asset.getPrice(for: usd), "the registry price is there to be distrusted")
            XCTAssertEqual(AssetTrustResolver.priceTrust(for: untrusted, currency: usd), .unavailable)
            XCTAssertFalse(AssetTrustResolver.priceTrust(for: untrusted, currency: usd).contributesToPortfolioTotal)
            XCTAssertNil(AssetTrustResolver.trustedPrice(for: untrusted, currency: usd))
            XCTAssertEqual(AssetTrustResolver.priceTrust(for: control, currency: usd), .canonicalAsset)
            XCTAssertEqual(AssetTrustResolver.trustedPrice(for: control, currency: usd)?.price, "1")
            XCTAssertEqual(
                AssetTrustResolver.priceTrust(
                    for: untrusted,
                    currency: usd,
                    untrustedPrices: PortfolioUntrustedPriceList(entries: [])
                ),
                .canonicalAsset,
                "only the list withholds the price"
            )

            // Header total, and the wallet-management total.
            let header = try XCTUnwrap(
                WalletBalanceBuilder().buildBalance(for: accountInfos, [wallet], [untrusted, control])?[wallet.metaId]
            )
            XCTAssertEqual(header.enabledAssetFiatBalance, 5, entry.assetId)
            XCTAssertEqual(header.totalFiatValue, 5, entry.assetId)
            XCTAssertEqual(header.exclusions.unpricedCount, 1, "counted as an asset without price")

            // Portfolio row and network subtotal.
            let viewModel = ChainAssetListViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
                .buildViewModel(
                    wallet: wallet,
                    chainAssets: [untrusted, control],
                    locale: Locale(identifier: "en_US"),
                    accountInfos: accountInfos,
                    chainsWithIssue: [],
                    shouldRunManageAssetAnimate: false,
                    displayType: .assetChains,
                    chainSettings: [],
                    networkFilter: nil,
                    search: nil
                )
            let untrustedSection = try XCTUnwrap(viewModel.networkSections.first { $0.chainId == untrusted.chain.chainId })
            let untrustedRow = try XCTUnwrap(untrustedSection.rows.first { $0.chainAsset.assetKey == untrusted.assetKey })
            XCTAssertNil(untrustedSection.fiatSubtotal, "the holding keeps its row but has no fiat subtotal")
            XCTAssertEqual(untrustedRow.totalAmountString, .normal(nil))
            guard case let .normalAttributed(priceText) = untrustedRow.priceAttributedString else {
                return XCTFail("the row explains its missing fiat")
            }
            XCTAssertEqual(priceText?.string, PortfolioTestCopy.text("portfolio.asset.price_unavailable"))
            XCTAssertEqual(
                viewModel.exclusions,
                [PortfolioExclusionCaption(kind: .unpricedAssets, text: PortfolioTestCopy.text("portfolio.exclusions.unpriced.one", 1))]
            )

            let controlSection = try XCTUnwrap(viewModel.networkSections.first { $0.chainId == control.chain.chainId })
            let controlRow = try XCTUnwrap(controlSection.rows.first { $0.chainAsset.assetKey == control.assetKey })
            XCTAssertEqual(controlSection.fiatSubtotal, "$5")
            XCTAssertEqual(controlRow.totalAmountString, .normal("$5"))
            XCTAssertNotEqual(controlRow.priceAttributedString, .normalAttributed(nil))
        }
    }

    /// The screens that show one holding (asset details, Send, Receive and the Send asset picker) read
    /// `AssetTrustResolver.displayPrice`, so a listed asset shows no fiat there either.
    func testUntrustedAssetsShowNoFiatOutsideThePortfolio() throws {
        let usd = Currency.defaultCurrency()
        let wallet = AccountGenerator.generateMetaAccount()
        let control = try registryChainAsset(symbol: "usdt", network: "Polkadot AssetHub")
        let chainAssets = try registryChainAssets()

        for entry in PortfolioUntrustedPriceList.bundled.entries {
            let untrusted = try XCTUnwrap(chainAssets.first {
                $0.chain.chainId == entry.chainId && $0.asset.id == entry.assetId
            })
            ExactAssetPriceCache.shared.upsert(Set([untrusted.asset.priceId, control.asset.priceId].compactMap { $0 }).map {
                PriceData(currencyId: usd.id, priceId: $0, price: "1", fiatDayChange: nil, coingeckoPriceId: $0)
            })
            let accountInfos = try balances(wallet: wallet, values: [
                untrusted: BigUInt(1_000_000) * BigUInt(10).power(Int(untrusted.asset.precision)),
                control: BigUInt(5) * BigUInt(10).power(Int(control.asset.precision))
            ])

            XCTAssertNil(AssetTrustResolver.displayPrice(for: untrusted, currency: usd), entry.assetId)
            XCTAssertEqual(AssetTrustResolver.displayPrice(for: control, currency: usd)?.price, "1")
            XCTAssertEqual(
                AssetTrustResolver.displayPrice(
                    for: untrusted,
                    currency: usd,
                    untrustedPrices: PortfolioUntrustedPriceList(entries: [])
                )?.price,
                "1",
                "only the list withholds the price"
            )

            let picker = SelectAssetViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())
                .buildViewModel(
                    wallet: wallet,
                    chainAssets: [untrusted, control],
                    accountInfos: accountInfos,
                    locale: Locale(identifier: "en_US"),
                    selectedAssetId: nil
                )
            let untrustedCell = try XCTUnwrap(picker.first { $0.name == untrusted.chain.name })
            let controlCell = try XCTUnwrap(picker.first { $0.name == control.chain.name })
            XCTAssertNil(untrustedCell.fiatBalanceString, "a million look-alike tokens are not a million dollars")
            XCTAssertNil(untrustedCell.fiatBalanceDecimal)
            XCTAssertEqual(untrustedCell.balanceDecimal, 1_000_000, "the balance itself stays")
            XCTAssertEqual(controlCell.fiatBalanceDecimal, 5)
            XCTAssertEqual(picker.first?.name, control.chain.name, "the picker no longer ranks it by a borrowed price")
        }
    }

    // MARK: - Testnet and zero-default lists

    func testTestnetListCoversNetworksWithoutTheRegistryOption() throws {
        let testnets = PortfolioTestnetChainList.bundled
        let chains = try registryChains()

        func chain(named name: String) throws -> ChainModel {
            try XCTUnwrap(chains.first { $0.name == name }, name)
        }

        for name in ["CAGA Ankara Testnet", "Avail Turing Testnet", "Kusama (test)", "Polkadot (test)", "Analog Testnet"] {
            let chain = try chain(named: name)
            XCTAssertFalse(chain.isTestnet, "\(name) gained the registry option; the list is no longer the only guard")
            XCTAssertTrue(testnets.isTestnet(chain), name)
        }
        for name in ["Westend", "Canary Matrixchain", "Moonbase Alpha"] {
            XCTAssertTrue(testnets.isTestnet(try chain(named: name)), name)
        }
        for name in ["Polkadot", "Kusama", "Ethereum", "SORA Mainnet", "TON Mainnet"] {
            XCTAssertFalse(testnets.isTestnet(try chain(named: name)), name)
        }
        for chain in chains where chain.isTestnet {
            XCTAssertTrue(testnets.chainIds.contains(chain.chainId.lowercased()), "\(chain.name) is a registry testnet but not listed")
        }
        XCTAssertTrue(testnets.isTestnet(UniversalWalletRegistry.tairaChainModel))
        XCTAssertFalse(testnets.isTestnet(UniversalWalletRegistry.bitcoinMainnetChainModel))
        for chainId in ["bitcoin:testnet", "solana:devnet", "iroha3-taira"] {
            XCTAssertTrue(testnets.chainIds.contains(chainId), chainId)
        }
    }

    func testMissingTestnetListFallsBackToTheRegistryOption() throws {
        let testnets = PortfolioTestnetChainList(data: nil)
        let chains = try registryChains()

        XCTAssertFalse(testnets.isLoaded)
        XCTAssertTrue(testnets.isTestnet(try XCTUnwrap(chains.first { $0.name == "Westend" })))
        XCTAssertFalse(PortfolioTestnetChainList(data: Data("{\"format\":\"x\",\"version\":1,\"chainIds\":[]}".utf8)).isLoaded)
    }

    func testZeroDefaultParityCases() throws {
        let data = try XCTUnwrap(try Data(contentsOf: try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "parity-cases.v1", withExtension: "json", subdirectory: "Registry")
        )))
        XCTAssertEqual(sha256(data), Self.parityCasesSha256)

        struct ParityCases: Decodable {
            struct ZeroDefaultCase: Decodable {
                let id: String
                let accounts: [String]
                let sendPausedChainIds: [String]?
                let expected: [String]
            }

            let format: String
            let zeroDefaults: [ZeroDefaultCase]
        }

        let cases = try JSONDecoder().decode(ParityCases.self, from: data)
        XCTAssertEqual(cases.format, "fearless.portfolio-parity-cases")
        XCTAssertFalse(cases.zeroDefaults.isEmpty)

        let list = PortfolioZeroDefaultList.bundled
        for parityCase in cases.zeroDefaults {
            let families = Set(try parityCase.accounts.map { try XCTUnwrap(PortfolioAccountFamily(rawValue: $0), $0) })
            let labels = list.entries(
                for: families,
                sendVetoedChainIds: Set(parityCase.sendPausedChainIds ?? [])
            ).map { "\($0.symbol)@\($0.network)" }

            XCTAssertEqual(labels, parityCase.expected, parityCase.id)
        }
    }

    func testZeroDefaultsMatchOneUtilityAssetOfANonTestnetNetwork() throws {
        let list = PortfolioZeroDefaultList.bundled
        let chainAssets = try registryChainAssets()
        let testnets = PortfolioTestnetChainList.bundled

        XCTAssertEqual(list.entries.count, 18)
        // The registry snapshot has no Solana row; Solana matches the network model the app
        // merges in at runtime, like Bitcoin.
        for entry in list.entries {
            let matches = chainAssets.filter { $0.chain.chainId == entry.chainId && list.contains($0) }
            XCTAssertEqual(matches.count, 1, "\(entry.symbol)@\(entry.network)")
            XCTAssertTrue(matches.allSatisfy { $0.isUtility && !testnets.isTestnet($0.chain) }, entry.network)
            XCTAssertNotNil(entry.accountFamily, entry.ecosystem)
        }
        XCTAssertFalse(chainAssets.contains { $0.chain.name == "X Layer Mainnet" && $0.asset.symbol.lowercased() == "wokb" && list.contains($0) })
        XCTAssertTrue(PortfolioZeroDefaultList(data: Data("{}".utf8)).entries.isEmpty)
    }

    func testAccountFamilyFollowsTheSharedEcosystemMapping() {
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "ethereum"), .evm)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "ethereumBased"), .evm)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "substrate"), .substrate)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "ton"), .ton)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "bitcoin"), .bitcoin)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "solana"), .solana)
        XCTAssertEqual(PortfolioAccountFamily(ecosystem: "iroha"), .iroha)
        XCTAssertNil(PortfolioAccountFamily(ecosystem: "evm"))
        XCTAssertNil(PortfolioAccountFamily(ecosystem: "cosmos"))
    }

    // MARK: - Helpers

    private func bundledCatalog() throws -> CanonicalTokenGroupCatalog {
        CanonicalTokenGroupCatalog(
            data: try bundledData(CanonicalTokenGroupCatalog.resourceName),
            testnets: PortfolioTestnetChainList.bundled,
            userDefaults: userDefaults
        )
    }

    private func bundledData(_ name: String) throws -> Data {
        try Data(contentsOf: try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json"), name))
    }

    private func bundledJSON(_ name: String) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: try bundledData(name)) as? [String: Any])
    }

    private func mutated(_ document: [String: Any], _ change: (inout [String: Any]) throws -> Void) throws -> Data {
        var document = document
        try change(&document)
        return try JSONSerialization.data(withJSONObject: document)
    }

    /// The reviewed registry snapshot decoded with the app's own parser, plus the networks the
    /// app merges in at runtime.
    private func registryChains() throws -> [ChainModel] {
        if let cachedRegistryChains {
            return cachedRegistryChains
        }

        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(sha256(data), Self.registrySnapshotSha256)

        let chains: [ChainModel]
        do {
            chains = try JSONDecoder().decode([ChainModel].self, from: data)
        } catch {
            chains = try JSONDecoder().decode(
                [ChainModel].self,
                from: try ChainSyncService.coerceChainsPayloadForCompatibility(data)
            )
        }
        XCTAssertEqual(chains.count, 116)
        let result = chains + UniversalWalletRegistry.appOwnedProductionChains
        cachedRegistryChains = result
        return result
    }

    private func registryChainAssets() throws -> [ChainAsset] {
        try registryChains().flatMap(\.chainAssets)
    }

    private func registryChainAsset(symbol: String, network: String) throws -> ChainAsset {
        let matches = try registryChainAssets().filter { $0.chain.name == network && $0.asset.symbol.lowercased() == symbol }
        XCTAssertEqual(matches.count, 1, "\(symbol) on \(network)")
        return try XCTUnwrap(matches.first, "\(symbol) on \(network)")
    }

    private func replacing(
        _ chainAsset: ChainAsset,
        assetId: String? = nil,
        symbol: String? = nil,
        precision: UInt16? = nil,
        priceId: String?? = .none
    ) -> ChainAsset {
        let asset = chainAsset.asset
        let replaced = AssetModel(
            id: assetId ?? asset.id,
            name: asset.name,
            symbol: symbol ?? asset.symbol,
            precision: precision ?? asset.precision,
            icon: asset.icon,
            currencyId: asset.currencyId,
            existentialDeposit: asset.existentialDeposit,
            color: asset.color,
            isUtility: asset.isUtility,
            isNative: asset.isNative,
            staking: asset.staking,
            purchaseProviders: asset.purchaseProviders,
            type: asset.type,
            ethereumType: asset.ethereumType,
            priceProvider: asset.priceProvider,
            coingeckoPriceId: priceId ?? asset.coingeckoPriceId
        )
        return ChainAsset(chain: chainAsset.chain, asset: replaced)
    }

    private func replacing(
        _ chainAsset: ChainAsset,
        chainOptions: [ChainOptions]? = nil,
        disabled: Bool? = nil
    ) -> ChainAsset {
        let chain = chainAsset.chain
        let replaced = ChainModel(
            rank: chain.rank,
            disabled: disabled ?? chain.disabled,
            chainId: chain.chainId,
            parentId: chain.parentId,
            paraId: chain.paraId,
            name: chain.name,
            assets: chain.assets,
            xcm: chain.xcm,
            nodes: chain.nodes,
            addressPrefix: chain.addressPrefix,
            types: chain.types,
            icon: chain.icon,
            options: chainOptions ?? chain.options,
            externalApi: chain.externalApi,
            selectedNode: chain.selectedNode,
            customNodes: chain.customNodes,
            iosMinAppVersion: chain.iosMinAppVersion,
            identityChain: chain.identityChain
        )
        return ChainAsset(chain: replaced, asset: chainAsset.asset)
    }

    private func balances(
        wallet: MetaAccountModel,
        values: [ChainAsset: BigUInt]
    ) throws -> [ChainAssetKey: AccountInfo?] {
        try Dictionary(uniqueKeysWithValues: values.map { chainAsset, value in
            let account = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest()), chainAsset.chain.name)
            return (
                chainAsset.uniqueKey(accountId: account.accountId),
                AccountInfo(
                    nonce: 0,
                    consumers: 0,
                    providers: 0,
                    data: AccountData(free: value, reserved: 0, frozen: 0, flags: 0)
                )
            )
        })
    }

    private func memberKey(_ chainId: String, _ assetId: String) -> String {
        "\(chainId.lowercased())/\(assetId)"
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
