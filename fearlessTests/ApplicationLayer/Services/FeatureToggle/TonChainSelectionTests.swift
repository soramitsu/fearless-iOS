import XCTest
@testable import fearless
import SSFModels

final class TonChainSelectionTests: XCTestCase {
    func testSelectedChainIdReturnsTestnetWhenEnabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: true)

        XCTAssertEqual(chainId, "-3")
    }

    func testSelectedChainIdReturnsMainnetWhenDisabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: false)

        XCTAssertEqual(chainId, "-239")
    }

    func testMatchesSelectedEnvironmentReturnsTrueForTestnetChainWhenEnabled() {
        let chain = makeChain(options: [.testnet])

        XCTAssertTrue(TonChainSelection.matchesSelectedEnvironment(chain: chain, isTestnetEnabled: true))
    }

    func testMatchesSelectedEnvironmentReturnsFalseForMainnetChainWhenEnabled() {
        let chain = makeChain(options: nil)

        XCTAssertFalse(TonChainSelection.matchesSelectedEnvironment(chain: chain, isTestnetEnabled: true))
    }

    private func makeChain(options: [ChainOptions]?) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://ton.node.test")!,
            name: "TON Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "ton-test-chain",
            parentId: nil,
            paraId: nil,
            name: "Ton Test",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
