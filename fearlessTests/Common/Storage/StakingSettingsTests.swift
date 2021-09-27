import XCTest
@testable import fearless
import SoraKeystore
import RobinHood

class StakingSettingsTests: XCTestCase {
    func testSetupWhenChainAssetExists() throws {
        // given

        let (stakingSettings, chains) = prepare()

        let chain = chains.first!
        let asset = chain.assets.first!
        stakingSettings.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

        // when

        stakingSettings.setup()

        // then

        let expectedValue = ChainAsset(chain: chain, asset: asset)
        let actualValue = stakingSettings.value
        XCTAssertEqual(expectedValue, actualValue)
    }

    func testSetupWhenChainAssetNotExists() throws {
        // given

        let (stakingSettings, chains) = prepare()

        let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 42)
        let asset = chain.assets.first!
        let settingValue = ChainAsset(chain: chain, asset: asset)
        stakingSettings.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

        // when

        stakingSettings.setup()

        // then

        XCTAssertNotEqual(settingValue, stakingSettings.value)

        guard let persistentChain = chains.first(
                where: { $0.chainId == stakingSettings.value.chain.chainId }
        ) else {
            XCTFail("Unexpected chain")
            return
        }

        XCTAssertTrue(persistentChain.assets.contains(stakingSettings.value.asset))
    }

    func testSetupWhenChainAssetNotSelected() throws {
        // given

        let (stakingSettings, chains) = prepare()

        // when

        stakingSettings.setup()

        // then

        guard let persistentChain = chains.first(
                where: { $0.chainId == stakingSettings.value.chain.chainId }
        ) else {
            XCTFail("Unexpected chain")
            return
        }

        XCTAssertTrue(persistentChain.assets.contains(stakingSettings.value.asset))
    }

    func testSaveWhenChainAssetExists() throws {
        // given

        let (stakingSettings, chains) = prepare()

        let chain = chains.first!
        let asset = chain.assets.first!
        stakingSettings.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)

        // when

        stakingSettings.setup()

        let newChain = chains.last!
        let newAsset = newChain.assets.first!
        let newSettingValue = ChainAsset(chain: newChain, asset: newAsset)
        stakingSettings.save(value: newSettingValue)

        // then

        XCTAssertEqual(newSettingValue, stakingSettings.value)

        let expectedChainId = ChainAssetId(chainId: newChain.chainId, assetId: newAsset.assetId)
        XCTAssertEqual(expectedChainId, stakingSettings.settings.stakingAsset)
    }

    func testSaveWhenChainNotSet() throws {
        // given

        let (stakingSettings, chains) = prepare()

        // when

        stakingSettings.setup()

        let newChain = chains.last!
        let newAsset = newChain.assets.first!
        let newSettingValue = ChainAsset(chain: newChain, asset: newAsset)
        stakingSettings.save(value: newSettingValue)

        // then

        XCTAssertEqual(newSettingValue, stakingSettings.value)

        let expectedChainId = ChainAssetId(chainId: newChain.chainId, assetId: newAsset.assetId)
        XCTAssertEqual(expectedChainId, stakingSettings.settings.stakingAsset)
    }

    private func prepare() -> (StakingAssetSettings, [ChainModel]) {
        let facade = SubstrateStorageTestFacade()

        let chainMapper = AnyCoreDataMapper(ChainModelMapper())
        let repository = facade.createRepository(mapper: chainMapper)

        let prefs = InMemorySettingsManager()
        let operationQueue = OperationQueue()

        let settings = StakingAssetSettings(
            storageFacade: facade,
            settings: prefs,
            operationQueue: operationQueue
        )

        let chains: [ChainModel] = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: UInt16(index),
                hasStaking: true
            )
        }

        let saveOperation = repository.saveOperation({ chains }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        return (settings, chains)
    }
}
