import XCTest
@testable import fearless
import FearlessSecureStorage
import SSFModels

final class CrowdloanSettingsTests: XCTestCase {
    func testCrowdloanChainId_whenSet_thenStoresSelectedChainId() {
        let settings = InMemorySettingsManager()

        settings.crowdloanChainId = "chain-id"

        XCTAssertEqual(settings.crowdloanChainId, "chain-id")
    }

    func testCrowdloanChainId_whenCleared_thenRemovesSelectedChainId() {
        let settings = InMemorySettingsManager()
        settings.crowdloanChainId = "chain-id"

        settings.crowdloanChainId = nil

        XCTAssertNil(settings.crowdloanChainId)
    }

    func testSave_whenChainProvided_thenUpdatesCurrentValueAndStoredChainId() {
        let settings = InMemorySettingsManager()
        let crowdloanSettings = CrowdloanChainSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: settings,
            operationQueue: OperationQueue()
        )
        let chain = makeChain()

        crowdloanSettings.save(value: chain)

        XCTAssertEqual(crowdloanSettings.value, chain)
        XCTAssertEqual(settings.crowdloanChainId, chain.chainId)
    }

    private func makeChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: nil,
            name: "Crowdloan Chain",
            assets: [],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "wss://example.org")!,
                    name: "Main",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://example.org/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}
