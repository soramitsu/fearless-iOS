import XCTest
@testable import fearless
import FearlessSecureStorage
import SSFModels

final class StakingSettingsTests: XCTestCase {
    func testStakingAsset_whenSet_thenStoresSelectedChainAssetId() {
        let settings = InMemorySettingsManager()
        let chainAssetId = ChainAssetId(chainId: "chain-id", assetId: "asset-id")

        settings.stakingAsset = chainAssetId

        XCTAssertEqual(settings.stakingAsset, chainAssetId)
    }

    func testStakingAsset_whenCleared_thenRemovesSelectedChainAssetId() {
        let settings = InMemorySettingsManager()
        settings.stakingAsset = ChainAssetId(chainId: "chain-id", assetId: "asset-id")

        settings.stakingAsset = nil

        XCTAssertNil(settings.stakingAsset)
    }

    func testSetup_whenNoPersistedChainsExist_thenKeepsValueEmpty() throws {
        let stakingSettings = makeSettings()
        let setupExpectation = expectation(description: "Staking asset settings setup")
        var setupResult: Result<ChainAsset?, Error>?

        stakingSettings.setup(runningCompletionIn: .main) { result in
            setupResult = result
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertNil(try XCTUnwrap(setupResult).get())
        XCTAssertNil(stakingSettings.value)
        XCTAssertNil(stakingSettings.settings.stakingAsset)
    }

    func testSave_whenChainAssetProvided_thenUpdatesCurrentValueAndStoredChainAssetId() throws {
        let stakingSettings = makeSettings()
        let chainAsset = try makeChainAsset()

        stakingSettings.save(value: chainAsset)

        XCTAssertEqual(stakingSettings.value, chainAsset)
        XCTAssertEqual(stakingSettings.settings.stakingAsset, chainAsset.chainAssetId)
    }

    private func makeSettings() -> StakingAssetSettings {
        StakingAssetSettings(
            storageFacade: SubstrateStorageTestFacade(),
            settings: InMemorySettingsManager(),
            operationQueue: OperationQueue(),
            wallet: AccountGenerator.generateMetaAccount()
        )
    }

    private func makeChainAsset() throws -> ChainAsset {
        let asset = AssetModel(
            id: "asset-id",
            name: "DOT",
            symbol: "dot",
            precision: 10,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        let nodeURL = try XCTUnwrap(URL(string: "wss://example.org"))
        let iconURL = try XCTUnwrap(URL(string: "https://example.org/icon.png"))
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: "chain-id",
            parentId: nil,
            paraId: nil,
            name: "Staking Chain",
            assets: [asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: nodeURL,
                    name: "Main",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: iconURL,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )

        return ChainAsset(chain: chain, asset: asset)
    }
}
