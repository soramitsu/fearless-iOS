import XCTest
import RobinHood
import SSFModels
@testable import fearless

final class NetworkRetirementTests: XCTestCase {
    func testRetiredNetworksAreLeftOutOfDownloadedLists() {
        let moonbeam = makeChain(chainId: Chain.moonbeam.genesisHash, name: "Moonbeam")
        let zkEvm = makeChain(chainId: "1101", name: "Polygon zkEVM")
        let acala = makeChain(chainId: Chain.acala.genesisHash, name: "Acala")

        let kept = NetworkRetirement.applying(to: [moonbeam, acala, zkEvm])

        XCTAssertEqual(kept.map(\.chainId), [Chain.acala.genesisHash])
    }

    func testRetiredNetworksDoNotIncludeNetworksThatStillProduceBlocks() {
        let liveChainIds: [ChainModel.Id] = [
            Chain.polkadot.genesisHash,
            Chain.kusama.genesisHash,
            Chain.westend.genesisHash,
            Chain.acala.genesisHash,
            Chain.liberland.genesisHash,
            Chain.ternoa.genesisHash,
            Chain.soraMain.genesisHash,
            "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f", // Polkadot Asset Hub
            "48239ef607d7928874027a43a67689209727dfb3d3dc5e5b03a39bdc2eda771a", // Kusama Asset Hub
            // AvN left its relay chain but runs on its own: relay inclusion alone does not prove a network is gone.
            "8b5c955b5c8fd7112562327e3859473df4e3dff49bd72a113dbb668d2cfa20d7",
            "1", // Ethereum
            "10", // OP Mainnet
            "8217" // Kaia
        ]

        XCTAssertTrue(NetworkRetirement.retiredChainIds.isDisjoint(with: liveChainIds))
        XCTAssertTrue(
            NetworkRetirement.retiredChainIds.isDisjoint(
                with: NetworkRetirement.assetHubMigratedRelayChainIds
            )
        )
    }

    func testAssetHubMigratedRelayChainLosesStakingPoolsAndCrowdloans() throws {
        let node = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://rpc.polkadot.io")),
            name: "Parity node",
            apikey: nil
        )
        let polkadot = makeChain(
            chainId: Chain.polkadot.genesisHash,
            name: "Polkadot",
            staking: .relayChain,
            options: [.crowdloans, .poolStaking, .tipRequired],
            nodes: [node]
        )
        .replacingSelectedNode(node)

        let migrated = try XCTUnwrap(NetworkRetirement.applying(to: [polkadot]).first)

        XCTAssertTrue(migrated.assets.allSatisfy { $0.staking == nil })
        XCTAssertEqual(migrated.options, [.tipRequired])
        XCTAssertFalse(migrated.hasCrowdloans)
        XCTAssertEqual(migrated.assets.map(\.id), polkadot.assets.map(\.id))
        XCTAssertEqual(migrated.nodes, polkadot.nodes)
        XCTAssertEqual(migrated.selectedNode, node)
        XCTAssertFalse(migrated.disabled)
        XCTAssertNotEqual(migrated, polkadot, "the stored copy must be replaced on the next sync")
    }

    func testEveryAssetHubMigratedRelayChainLosesStaking() {
        for chainId in NetworkRetirement.assetHubMigratedRelayChainIds {
            let relay = makeChain(
                chainId: chainId,
                name: "Relay",
                staking: .relayChain,
                options: [.poolStaking]
            )

            let migrated = NetworkRetirement.applying(to: [relay])

            XCTAssertEqual(migrated.count, 1)
            XCTAssertNil(migrated.first?.assets.first?.staking, chainId)
            XCTAssertEqual(migrated.first?.options, [ChainOptions](), chainId)
        }
    }

    func testChainsWithTheirOwnStakingKeepIt() throws {
        let ternoa = makeChain(
            chainId: Chain.ternoa.genesisHash,
            name: "Ternoa Mainnet",
            staking: .relayChain,
            options: [.poolStaking]
        )

        let kept = try XCTUnwrap(NetworkRetirement.applying(to: [ternoa]).first)

        XCTAssertEqual(kept, ternoa)
        XCTAssertEqual(kept.assets.first?.staking, .relayChain)
        XCTAssertEqual(kept.options, [.poolStaking])
    }

    func testParachainStakingIsNoLongerOfferedOnAListedNetwork() throws {
        let node = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://wss.api.moonbase.moonbeam.network")),
            name: "Moonbeam Network node",
            apikey: nil
        )
        let token = AssetModel(
            id: "token", name: "Token", symbol: "TKN", precision: 6, isUtility: false, isNative: false
        )
        let moonbaseAlpha = makeChain(
            chainId: Chain.moonbaseAlpha.genesisHash,
            name: "Moonbase Alpha",
            staking: .paraChain,
            options: [.testnet],
            nodes: [node],
            extraAssets: [token]
        )
        .replacingSelectedNode(node)

        let offered = try XCTUnwrap(NetworkRetirement.applying(to: [moonbaseAlpha]).first)

        XCTAssertTrue(offered.assets.allSatisfy { $0.staking == nil })
        XCTAssertEqual(Set(offered.assets.map(\.id)), Set(moonbaseAlpha.assets.map(\.id)))
        XCTAssertEqual(offered.assets.first { $0.id == token.id }, token, "assets without staking are untouched")
        XCTAssertEqual(offered.options, [.testnet])
        XCTAssertEqual(offered.nodes, moonbaseAlpha.nodes)
        XCTAssertEqual(offered.selectedNode, node)
        XCTAssertEqual(offered.addressPrefix, moonbaseAlpha.addressPrefix)
        XCTAssertFalse(offered.disabled)
        XCTAssertTrue(offered.chainAssets.allSatisfy { $0.stakingType == nil })
        XCTAssertFalse(offered.assets.contains { $0.offersStaking })
        XCTAssertEqual(
            NetworkRetirement.storedUpdates(for: [moonbaseAlpha]).map(\.chainId),
            [moonbaseAlpha.chainId],
            "a stored copy loses the staking flag on the next sync"
        )
    }

    func testReefIsNoLongerOfferedButItsStoredCopyIsKept() throws {
        let reef = makeChain(chainId: Chain.reef.genesisHash, name: "Reef Mainnet", staking: .relayChain)
        let scuba = makeChain(chainId: Chain.scuba.genesisHash, name: "Reef Scuba Testnet", staking: .relayChain)
        let ternoa = makeChain(chainId: Chain.ternoa.genesisHash, name: "Ternoa Mainnet", staking: .relayChain)

        XCTAssertEqual(NetworkRetirement.applying(to: [reef, scuba, ternoa]).map(\.chainId), [ternoa.chainId])
        XCTAssertNil(NetworkRetirement.offered(reef))
        XCTAssertNil(NetworkRetirement.offered(scuba))

        let updates = NetworkRetirement.storedUpdates(for: [reef, scuba, ternoa])
        XCTAssertEqual(updates.map(\.chainId), [reef.chainId, scuba.chainId])
        XCTAssertTrue(updates.allSatisfy(\.disabled))
        XCTAssertEqual(updates.first?.assets, reef.assets, "saved balances keep their assets")
        XCTAssertTrue(NetworkRetirement.unsupportedChainIds.isDisjoint(with: NetworkRetirement.retiredChainIds))
        XCTAssertTrue(
            NetworkRetirement.unsupportedChainIds.isDisjoint(with: NetworkRetirement.assetHubMigratedRelayChainIds)
        )
    }

    func testStoredReefAndParachainStakingStillLoadAndKeepKeyAccessAfterCleanup() throws {
        let reefApiUrl = try XCTUnwrap(URL(string: "https://squid.subsquid.io/reef-explorer/graphql"))
        let reefApi = ChainModel.BlockExplorer(type: "reef", url: reefApiUrl)
        let reef = makeChain(
            chainId: Chain.reef.genesisHash,
            name: "Reef Mainnet",
            staking: .relayChain,
            externalApi: ChainModel.ExternalApiSet(
                staking: reefApi,
                history: reefApi,
                explorers: [
                    ChainModel.ExternalApiExplorer(
                        type: .reef,
                        types: [.account],
                        url: "https://reefscan.com/{type}/{value}"
                    )
                ]
            )
        )
        let moonbaseAlpha = makeChain(
            chainId: Chain.moonbaseAlpha.genesisHash,
            name: "Moonbase Alpha",
            staking: .paraChain,
            options: [.testnet]
        )
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        let queue = OperationQueue()
        let save = repository.saveOperation({ [reef, moonbaseAlpha] }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        let _: Void = try save.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let stored = try fetchAll(from: repository, on: queue)
        let storedReef = try XCTUnwrap(stored.first { $0.chainId == reef.chainId })
        XCTAssertEqual(storedReef.externalApi?.staking?.type, .reef)
        XCTAssertEqual(storedReef.externalApi?.history?.type, .reef)
        XCTAssertEqual(storedReef.externalApi?.explorers?.first?.type, .reef)
        let storedMoonbase = try XCTUnwrap(stored.first { $0.chainId == moonbaseAlpha.chainId })
        XCTAssertEqual(storedMoonbase.assets.first?.staking, .paraChain)

        let cleanup = repository.saveOperation({ NetworkRetirement.storedUpdates(for: stored) }, { [] })
        queue.addOperations([cleanup], waitUntilFinished: true)
        let _: Void = try cleanup.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        let cleaned = try fetchAll(from: repository, on: queue)
        XCTAssertEqual(Set(cleaned.map(\.chainId)), [reef.chainId, moonbaseAlpha.chainId], "nothing is deleted")
        let cleanedReef = try XCTUnwrap(cleaned.first { $0.chainId == reef.chainId })
        XCTAssertTrue(cleanedReef.disabled)
        XCTAssertEqual(cleanedReef.assets.map(\.id), reef.assets.map(\.id))
        XCTAssertEqual(cleanedReef.externalApi?.explorers?.first?.type, .reef)
        let cleanedMoonbase = try XCTUnwrap(cleaned.first { $0.chainId == moonbaseAlpha.chainId })
        XCTAssertFalse(cleanedMoonbase.disabled)
        XCTAssertNil(cleanedMoonbase.assets.first?.staking)
        XCTAssertTrue(NetworkRetirement.applying(to: cleaned).allSatisfy { $0.chainId == moonbaseAlpha.chainId })

        let reefAccount = ChainAccountModel(
            chainId: reef.chainId,
            accountId: Data(repeating: 1, count: 32),
            publicKey: Data(repeating: 2, count: 32),
            cryptoType: 0,
            ethereumBased: false
        )
        let walletWithReefKey = AccountGenerator.generateMetaAccount(with: [reefAccount])
        XCTAssertEqual(
            Set(cleaned.listedForKeyAccess(by: walletWithReefKey).map(\.chainId)),
            [reef.chainId, moonbaseAlpha.chainId],
            "a wallet's own Reef key can still be viewed and exported"
        )
        XCTAssertEqual(
            cleaned.listedForKeyAccess(by: AccountGenerator.generateMetaAccount()).map(\.chainId),
            [moonbaseAlpha.chainId]
        )
    }

    func testStoredChainsAreRetiredOrStrippedWithoutDeletion() throws {
        let moonbeam = makeChain(chainId: Chain.moonbeam.genesisHash, name: "Moonbeam", staking: .paraChain)
        let alreadyDisabled = makeChain(chainId: "1101", name: "Polygon zkEVM").replacingDisabled(true)
        let polkadot = makeChain(
            chainId: Chain.polkadot.genesisHash,
            name: "Polkadot",
            staking: .relayChain,
            options: [.poolStaking]
        )
        let acala = makeChain(chainId: Chain.acala.genesisHash, name: "Acala")

        let updates = NetworkRetirement.storedUpdates(for: [moonbeam, alreadyDisabled, polkadot, acala])

        XCTAssertEqual(updates.map(\.chainId), [moonbeam.chainId, polkadot.chainId])
        let retired = try XCTUnwrap(updates.first)
        XCTAssertTrue(retired.disabled)
        XCTAssertEqual(retired.assets, moonbeam.assets, "saved balances keep their assets")
        XCTAssertNil(updates.last?.assets.first?.staking)
        XCTAssertEqual(updates.last?.options, [ChainOptions]())
        XCTAssertNil(NetworkRetirement.offered(moonbeam))
        XCTAssertTrue(NetworkRetirement.offered(acala) === acala)
    }

    func testWalletScreensKeepARetiredNetworkWhereAStoredAlternativeKeyLives() {
        let storedAlternative = AccountGenerator.generateChainAccount()
        let wallet = AccountGenerator.generateMetaAccount()
        let retired = makeChain(chainId: storedAlternative.chainId, name: "Retired with stored key")
            .replacingDisabled(true)

        XCTAssertTrue([retired].listedForKeyAccess(by: wallet).isEmpty)
        XCTAssertEqual(
            [retired].listedForKeyAccess(by: wallet, storedAccounts: [storedAlternative]).map(\.chainId),
            [retired.chainId]
        )
    }

    func testWalletScreensKeepARetiredNetworkWhereTheWalletHasItsOwnKey() {
        let ownAccount = AccountGenerator.generateChainAccount()
        let wallet = AccountGenerator.generateMetaAccount(with: [ownAccount])
        let enabled = makeChain(chainId: Chain.acala.genesisHash, name: "Acala")
        let retiredWithOwnKey = makeChain(chainId: ownAccount.chainId, name: "Retired with own key")
            .replacingDisabled(true)
        let retiredWithoutOwnKey = makeChain(chainId: Chain.moonbeam.genesisHash, name: "Moonbeam")
            .replacingDisabled(true)

        let listed = [enabled, retiredWithOwnKey, retiredWithoutOwnKey].listedForKeyAccess(by: wallet)

        XCTAssertEqual(listed.map(\.chainId), [enabled.chainId, retiredWithOwnKey.chainId])
    }

    private func makeChain(
        chainId: ChainModel.Id,
        name: String,
        staking: RawStakingType? = nil,
        options: [ChainOptions]? = nil,
        nodes: Set<ChainNodeModel> = [],
        extraAssets: Set<AssetModel> = [],
        externalApi: ChainModel.ExternalApiSet? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            assets: extraAssets.union([
                AssetModel(
                    id: "\(name)-native",
                    name: name,
                    symbol: "NAT",
                    precision: 10,
                    isUtility: true,
                    isNative: true,
                    staking: staking
                )
            ]),
            xcm: nil,
            nodes: nodes,
            addressPrefix: 0,
            icon: nil,
            options: options,
            externalApi: externalApi,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func fetchAll(
        from repository: CoreDataRepository<ChainModel, CDChain>,
        on queue: OperationQueue
    ) throws -> [ChainModel] {
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        return try fetch.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }
}
