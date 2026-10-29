import XCTest
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
        nodes: Set<ChainNodeModel> = []
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            assets: [
                AssetModel(
                    id: "\(name)-native",
                    name: name,
                    symbol: "NAT",
                    precision: 10,
                    isUtility: true,
                    isNative: true,
                    staking: staking
                )
            ],
            xcm: nil,
            nodes: nodes,
            addressPrefix: 0,
            icon: nil,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
