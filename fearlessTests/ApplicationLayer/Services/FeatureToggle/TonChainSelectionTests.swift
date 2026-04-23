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

final class TonCompatibilityTests: XCTestCase {
    func testTonCompatibilityChainDetectionByExplorerURL() {
        let chain = makeTonCompatibilityChain(
            name: "Any Name",
            chainId: "custom-chain",
            nodeURL: URL(string: "wss://node.example.com")!,
            explorerURL: URL(string: "https://tonviewer.com/address/abc")!
        )

        XCTAssertTrue(chain.isTonCompatibilityChain)
    }

    func testTonCompatibilityChainDetectionByNodeURL() {
        let chain = makeTonCompatibilityChain(
            name: "Any Name",
            chainId: "custom-chain",
            nodeURL: URL(string: "wss://rpc.ton.org")!,
            explorerURL: URL(string: "https://explorer.example.com/address/abc")!
        )

        XCTAssertTrue(chain.isTonCompatibilityChain)
    }

    func testTonCompatibilityChainDetectionReturnsFalseForNonTonChain() {
        let chain = makeTonCompatibilityChain(
            name: "Polkadot",
            chainId: "polkadot-mainnet",
            nodeURL: URL(string: "wss://rpc.polkadot.io")!,
            explorerURL: URL(string: "https://polkadot.subscan.io")!
        )

        XCTAssertFalse(chain.isTonCompatibilityChain)
    }

    func testTonAssetTypeMapsNormal() {
        let type: SubstrateAssetType? = .normal

        XCTAssertEqual(type.tonAssetType, .normal)
    }

    func testTonAssetTypeMapsJettonForNonNormalType() {
        let type: SubstrateAssetType? = .ormlAsset

        XCTAssertEqual(type.tonAssetType, .jetton)
    }

    func testTonAssetTypeMapsNoneForMissingType() {
        let type: SubstrateAssetType? = nil

        XCTAssertEqual(type.tonAssetType, .none)
    }

    func testDataTailReturnsSuffixWhenDataIsLongerThanLength() {
        let data = Data([0x01, 0x02, 0x03, 0x04])

        XCTAssertEqual(data.tail(2), Data([0x03, 0x04]))
    }

    func testDataTailReturnsOriginalDataWhenLengthExceedsCount() {
        let data = Data([0xAA, 0xBB])

        XCTAssertEqual(data.tail(8), data)
    }

    private func makeTonCompatibilityChain(
        name: String,
        chainId: String,
        nodeURL: URL,
        explorerURL: URL
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: nodeURL,
            name: "Node",
            apikey: nil
        )

        let explorers = [
            ChainModel.ExternalApiExplorer(
                type: .unknown,
                types: [],
                url: explorerURL.absoluteString
            )
        ]

        let externalApi = ChainModel.ExternalApiSet(
            staking: nil,
            history: nil,
            crowdloans: nil,
            explorers: explorers,
            pricing: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class TonRemoteBalanceFetchingParsingTests: XCTestCase {
    func testParseFiatDayChangePercentStripsPercentSign() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("4.25%")

        XCTAssertEqual(value, Decimal(string: "4.25"))
    }

    func testParseFiatDayChangePercentNormalizesUnicodeMinusSign() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("−1.75%")

        XCTAssertEqual(value, Decimal(string: "-1.75"))
    }

    func testParseFiatDayChangePercentDefaultsToZeroForInvalidInput() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("n/a")

        XCTAssertEqual(value, .zero)
    }
}
