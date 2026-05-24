import XCTest
@testable import fearless
import RobinHood
import SSFModels
import SSFNetwork
import SSFStorageQueryKit
import SSFUtils
import SSFRuntimeCodingService
import BigInt

final class TonChainSelectionTests: XCTestCase {
    func testSelectedChainIdReturnsTestnetWhenEnabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: true)

        XCTAssertEqual(chainId, "-3")
    }

    func testSelectedChainIdReturnsMainnetWhenDisabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: false)

        XCTAssertEqual(chainId, "-239")
    }

    func testSelectedChainIdUsesInjectedToggleSource() {
        let testnetSource = TonChainSelectionToggleSourceStub(
            tonEnvListToggle: LocalListToggle.tonEnv.toggle()
        )
        let mainnetSource = TonChainSelectionToggleSourceStub(
            tonEnvListToggle: LocalListToggle.tonEnv
        )

        XCTAssertEqual(
            TonChainSelection.selectedChainId(toggleSource: testnetSource),
            TonChainSelection.testnetChainId
        )
        XCTAssertEqual(
            TonChainSelection.selectedChainId(toggleSource: mainnetSource),
            TonChainSelection.mainnetChainId
        )
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

private struct TonChainSelectionToggleSourceStub: TonChainSelection.ToggleSource {
    let tonEnvListToggle: LocalListToggle
}

final class LocalListToggleTests: XCTestCase {
    func testToggle_whenCalled_thenKeepsMetadataAndInvertsStorageValue() {
        let toggle = LocalListToggle(
            key: "feature-key",
            title: "Feature",
            description: "Feature description",
            storageValue: false
        )

        let toggled = toggle.toggle()

        XCTAssertEqual(toggled.key, toggle.key)
        XCTAssertEqual(toggled.title, toggle.title)
        XCTAssertEqual(toggled.description, toggle.description)
        XCTAssertTrue(toggled.storageValue)
        XCTAssertFalse(toggled.toggle().storageValue)
    }
}

final class TonJettonInjectorTests: XCTestCase {
    func testInjectPriceDataUsesInjectedTonToggleSource() async {
        let repository = AsyncChainRepositoryStub(
            models: [
                makeTonChain(chainId: TonChainSelection.mainnetChainId, name: "TON", options: nil),
                makeTonChain(chainId: TonChainSelection.testnetChainId, name: "TON Test", options: [.testnet])
            ]
        )
        let eventCenter = TonJettonEventCenterSpy()
        let logger = TonJettonLoggerSpy()
        let injector = TonJettonInjectorImpl(
            chainModelRepository: AsyncAnyRepository(repository),
            eventCenter: eventCenter,
            logger: logger,
            tonChainSelectionToggleSource: TonChainSelectionToggleSourceStub(
                tonEnvListToggle: LocalListToggle.tonEnv.toggle()
            )
        )

        await injector.inject(tonPriceData: [
            PriceData(
                currencyId: "ton",
                priceId: "ton",
                price: "2.50",
                fiatDayChange: Decimal(string: "1.25"),
                coingeckoPriceId: "the-open-network"
            )
        ])

        XCTAssertEqual(repository.fetchedIds, [TonChainSelection.testnetChainId])
        XCTAssertEqual(repository.savedModels.map(\.chainId), [TonChainSelection.testnetChainId])
        XCTAssertEqual(repository.savedModels.last?.utilityAssets().first?.price, Decimal(string: "2.50"))
        XCTAssertEqual(repository.savedModels.last?.utilityAssets().first?.fiatDayChange, Decimal(string: "1.25"))
        XCTAssertEqual(repository.savedModels.last?.utilityAssets().first?.coingeckoPriceId, "old-ton")
        XCTAssertEqual(eventCenter.notifiedEventTypes, ["PricesUpdated"])
        XCTAssertTrue(logger.errors.isEmpty)
    }

    private func makeTonChain(
        chainId: ChainModel.Id,
        name: String,
        options: [ChainOptions]?
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://\(chainId.replacingOccurrences(of: "-", with: "minus")).ton.example")!,
            name: "\(name) Node",
            apikey: nil
        )
        let utilityAsset = AssetModel(
            id: "ton",
            name: "Toncoin",
            symbol: "TON",
            precision: 9,
            currencyId: "ton",
            isUtility: true,
            isNative: true,
            coingeckoPriceId: "old-ton"
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            paraId: nil,
            name: name,
            assets: [utilityAsset],
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            icon: nil,
            options: options,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class AsyncChainRepositoryStub: AsyncCoreDataRepository {
    typealias Model = ChainModel

    private var models: [ChainModel.Id: ChainModel]
    private(set) var fetchedIds: [ChainModel.Id] = []
    private(set) var savedModels: [ChainModel] = []

    init(models: [ChainModel]) {
        self.models = Dictionary(uniqueKeysWithValues: models.map { ($0.chainId, $0) })
    }

    func fetch(
        by modelIds: [String],
        options _: RepositoryFetchOptions
    ) async throws -> [ChainModel] {
        fetchedIds.append(contentsOf: modelIds)
        return modelIds.compactMap { models[$0] }
    }

    func fetch(
        by modelId: String,
        options _: RepositoryFetchOptions
    ) async throws -> ChainModel? {
        fetchedIds.append(modelId)
        return models[modelId]
    }

    func fetchAll(with _: RepositoryFetchOptions) async throws -> [ChainModel] {
        Array(models.values)
    }

    func save(
        models: [ChainModel],
        deleteIds: [String]
    ) async {
        savedModels.append(contentsOf: models)

        deleteIds.forEach { self.models[$0] = nil }
        models.forEach { self.models[$0.chainId] = $0 }
    }
}

private final class TonJettonEventCenterSpy: EventCenterProtocol {
    private(set) var notifiedEventTypes: [String] = []

    func notify(with event: EventProtocol) {
        notifiedEventTypes.append(String(describing: type(of: event)))
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private final class TonJettonLoggerSpy: LoggerProtocol {
    private(set) var errors: [Error] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}

    func customError(error: Error, file _: String, function _: String, line _: Int) {
        errors.append(error)
    }
}

final class LocalToggleServiceTests: XCTestCase {
    private let suiteName = "Feature.Toggle.List"

    override func setUp() {
        super.setUp()

        resetToggleStorage()
    }

    override func tearDown() {
        resetToggleStorage()
        LocalToggleService.shared.setup()

        super.tearDown()
    }

    func testSetup_whenStorageIsEmpty_thenPersistsDefaultToggles() {
        LocalToggleService.shared.setup()

        XCTAssertEqual(LocalToggleService.shared.chainsListToggle?.key, LocalListToggle.chains.key)
        XCTAssertEqual(LocalToggleService.shared.chainsListToggle?.storageValue, LocalListToggle.chains.storageValue)
        XCTAssertEqual(LocalToggleService.shared.tonEnvListToggle.key, LocalListToggle.tonEnv.key)
        XCTAssertEqual(LocalToggleService.shared.tonEnvListToggle.storageValue, LocalListToggle.tonEnv.storageValue)
    }

    func testToggleProperties_whenUpdated_thenPersistValuesAndDriveTonSelection() {
        LocalToggleService.shared.setup()

        LocalToggleService.shared.chainsListToggle = LocalListToggle.chains.toggle()
        LocalToggleService.shared.tonEnvListToggle = LocalListToggle.tonEnv.toggle()

        XCTAssertEqual(LocalToggleService.shared.chainsListToggle?.storageValue, false)
        XCTAssertEqual(LocalToggleService.shared.tonEnvListToggle.storageValue, true)
        XCTAssertEqual(TonChainSelection.selectedChainId(), TonChainSelection.testnetChainId)
    }

    private func resetToggleStorage() {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected feature-toggle UserDefaults suite")
            return
        }

        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }
}

final class FeatureToggleProviderTests: XCTestCase {
    private let configURL = URL(string: "https://example.com/feature-toggle.json")!

    func testFetchConfigOperation_whenConfigURLMissing_thenReturnsDefaultAndSkipsNetwork() throws {
        let networkFactory = FeatureToggleNetworkFactorySpy(result: FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: false))
        let provider = FeatureToggleProvider(
            networkOperationFactory: networkFactory,
            operationQueue: OperationQueue(),
            configSource: FeatureToggleConfigSourceStub(featureToggleURL: nil)
        )

        let config = try fetchConfig(from: provider)

        XCTAssertEqual(config.pendulumCaseEnabled, FeatureToggleConfig.defaultConfig.pendulumCaseEnabled)
        XCTAssertEqual(config.nftEnabled, FeatureToggleConfig.defaultConfig.nftEnabled)
        XCTAssertTrue(networkFactory.receivedURLs.isEmpty)
    }

    func testFetchConfigOperation_whenRemoteReturnsConfig_thenReturnsRemoteConfigAndUsesConfiguredURL() throws {
        let remoteConfig = FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: false)
        let networkFactory = FeatureToggleNetworkFactorySpy(result: remoteConfig)
        let provider = FeatureToggleProvider(
            networkOperationFactory: networkFactory,
            operationQueue: OperationQueue(),
            configSource: FeatureToggleConfigSourceStub(featureToggleURL: configURL)
        )

        let config = try fetchConfig(from: provider)

        XCTAssertEqual(config.pendulumCaseEnabled, remoteConfig.pendulumCaseEnabled)
        XCTAssertEqual(config.nftEnabled, remoteConfig.nftEnabled)
        XCTAssertEqual(networkFactory.receivedURLs, [configURL])
    }

    func testFetchConfigOperation_whenRemoteReturnsNil_thenReturnsDefaultConfig() throws {
        let networkFactory = FeatureToggleNetworkFactorySpy(result: nil)
        let provider = FeatureToggleProvider(
            networkOperationFactory: networkFactory,
            operationQueue: OperationQueue(),
            configSource: FeatureToggleConfigSourceStub(featureToggleURL: configURL)
        )

        let config = try fetchConfig(from: provider)

        XCTAssertEqual(config.pendulumCaseEnabled, FeatureToggleConfig.defaultConfig.pendulumCaseEnabled)
        XCTAssertEqual(config.nftEnabled, FeatureToggleConfig.defaultConfig.nftEnabled)
        XCTAssertEqual(networkFactory.receivedURLs, [configURL])
    }

    func testFetchConfigOperation_whenProviderIsReleased_thenReturnsDefaultConfig() throws {
        var provider: FeatureToggleProvider? = FeatureToggleProvider(
            networkOperationFactory: FeatureToggleNetworkFactorySpy(result: nil),
            operationQueue: OperationQueue(),
            configSource: FeatureToggleConfigSourceStub(featureToggleURL: nil)
        )
        let fetchOperation = provider?.fetchConfigOperation()

        provider = nil

        guard let fetchOperation else {
            return XCTFail("Expected fetch operation")
        }

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)
        let config = try extractConfig(from: fetchOperation)

        XCTAssertEqual(config.pendulumCaseEnabled, FeatureToggleConfig.defaultConfig.pendulumCaseEnabled)
        XCTAssertEqual(config.nftEnabled, FeatureToggleConfig.defaultConfig.nftEnabled)
    }

    private func fetchConfig(from provider: FeatureToggleProvider) throws -> FeatureToggleConfig {
        let fetchOperation = provider.fetchConfigOperation()

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        return try extractConfig(from: fetchOperation)
    }

    private func extractConfig(from operation: BaseOperation<FeatureToggleConfig>) throws -> FeatureToggleConfig {
        guard let result = operation.result else {
            throw BaseOperationError.parentOperationCancelled
        }

        switch result {
        case let .success(config):
            return config
        case let .failure(error):
            throw error
        }
    }
}

private struct FeatureToggleConfigSourceStub: FeatureToggleConfigSource {
    let featureToggleURL: URL?
}

private final class FeatureToggleNetworkFactorySpy: NetworkOperationFactoryProtocol {
    private let operation: BaseOperation<FeatureToggleConfig?>
    private(set) var receivedURLs: [URL] = []

    init(result: FeatureToggleConfig?) {
        operation = ClosureOperation<FeatureToggleConfig?> { result }
    }

    func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T> {
        receivedURLs.append(url)
        return operation as! BaseOperation<T>
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

final class AccountInfoRemoteServiceTests: XCTestCase {
    func testFetchAccountInfosDelegatesTonChainToTonRemoteService() async throws {
        let chain = makeTonLikeChain()
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(result, tonService.fetchInfosResult)
        XCTAssertEqual(tonService.fetchInfosInvocations, 1)
        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosDelegatesEthereumChainToEthereumFetcher() async throws {
        let asset = AssetModel(
            id: "0x01",
            name: "Unit ETH",
            symbol: "UETH",
            precision: 18,
            isUtility: false,
            isNative: true,
            ethereumType: .normal
        )
        let chain = makeEthereumChain(with: asset)
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        let expectedMap: [ChainAsset: AccountInfo?] = Dictionary(
            uniqueKeysWithValues: chain.chainAssets.map { ($0, nil) }
        )
        ethereumFetching.fetchManyResult = expectedMap

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(result.count, expectedMap.count)
        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 1)
        XCTAssertEqual(tonService.fetchInfosInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosThrowsWhenTonServiceMissingForTonCompatibilityChain() async {
        let chain = makeTonLikeChain()
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: nil,
            storagePerformer: storagePerformer
        )

        do {
            _ = try await service.fetchAccountInfos(for: chain, wallet: wallet)
            XCTFail("Expected TON service missing error")
        } catch {
            XCTAssertTrue(String(describing: error).contains("TON remote fetching unavailable"))
        }

        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfoUsesEquilibriumRequestForGenshiroChain() async throws {
        let chain = makeGenshiroLikeChain()
        let chainAsset = try XCTUnwrap(chain.chainAssets.first)
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        _ = try await service.fetchAccountInfo(for: chainAsset, wallet: wallet)

        XCTAssertEqual(storagePerformer.performMixInvocations, 1)
        let requestTypeName = String(describing: type(of: try XCTUnwrap(storagePerformer.lastMixRequests.first)))
        XCTAssertEqual(requestTypeName, String(describing: EquilibriumAccountInfotorageRequest.self))
    }

    private func makeTonLikeChain() -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://rpc.ton.org")!,
            name: "TON",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "unit-ton-chain",
            parentId: nil,
            paraId: nil,
            name: "Ton Unit",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeEthereumChain(with asset: AssetModel) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://rpc.unit-eth.test")!,
            name: "Unit ETH",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "unit-eth-chain",
            parentId: nil,
            paraId: nil,
            name: "Unit Ethereum",
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: [.ethereum],
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeGenshiroLikeChain() -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://node.ksm.genshiro.io")!,
            name: "Genshiro",
            apikey: nil
        )
        let asset = AssetModel(
            id: "gens-asset",
            name: "GENS",
            symbol: "GENS",
            precision: 12,
            isUtility: false,
            isNative: false,
            type: .normal
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "9de765698374eb576968c8a764168893fb277e65ad3ddafcfe2c49593fc6d663",
            parentId: nil,
            paraId: nil,
            name: "Genshiro",
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class ChainRegistryTonNodeSelectionTests: XCTestCase {
    func testResolveTonNodePrefersSelectedNode() {
        let primary = ChainNodeModel(
            url: URL(string: "https://ton-selected.example.com")!,
            name: "Selected",
            apikey: nil
        )
        let secondary = ChainNodeModel(
            url: URL(string: "https://ton-fallback.example.com")!,
            name: "Fallback",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [primary, secondary], selectedNode: primary)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertEqual(resolved?.url, primary.url)
    }

    func testResolveTonNodeFallsBackDeterministicallyWhenSelectedNodeMissing() {
        let nodeB = ChainNodeModel(
            url: URL(string: "https://b-ton.example.com")!,
            name: "B",
            apikey: nil
        )
        let nodeA = ChainNodeModel(
            url: URL(string: "https://a-ton.example.com")!,
            name: "A",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [nodeB, nodeA], selectedNode: nil)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertEqual(resolved?.url, nodeA.url)
    }

    func testResolveTonNodeReturnsNilForEmptyNodesAndNoSelection() {
        let chain = makeTonChain(nodes: [], selectedNode: nil)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertNil(resolved)
    }

    private func makeTonChain(nodes: [ChainNodeModel], selectedNode: ChainNodeModel?) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "-239",
            parentId: nil,
            paraId: nil,
            name: "TON Mainnet",
            xcm: nil,
            nodes: Set(nodes),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: selectedNode,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class CrossChainConfirmationViewModelFactoryTests: XCTestCase {
    func testCreateViewModelAddsOriginPreservationNoteForAssetHubChain() {
        let factory = CrossChainConfirmationViewModelFactory()
        let data = makeConfirmationData(destParaId: "1000")

        let viewModel = factory.createViewModel(with: data)

        XCTAssertEqual(viewModel.originPreservationNote, "Origin preserved via reserve transfer")
    }

    func testCreateViewModelSkipsOriginPreservationNoteForNonAssetHubChain() {
        let factory = CrossChainConfirmationViewModelFactory()
        let data = makeConfirmationData(destParaId: "2000")

        let viewModel = factory.createViewModel(with: data)

        XCTAssertNil(viewModel.originPreservationNote)
    }

    private func makeConfirmationData(destParaId: String) -> CrossChainConfirmationData {
        let wallet = AccountGenerator.generateMetaAccount()
        let originAsset = AssetModel(
            id: "origin-asset",
            name: "Origin Token",
            symbol: "ORG",
            precision: 12,
            color: "#3366FF",
            isUtility: true,
            isNative: true
        )
        let destAsset = AssetModel(
            id: "dest-asset",
            name: "Destination Token",
            symbol: "DST",
            precision: 12,
            color: "#33AA66",
            isUtility: true,
            isNative: true
        )
        let originChain = makeChain(
            chainId: "origin-chain",
            paraId: "0",
            name: "Origin Chain",
            asset: originAsset
        )
        let destChain = makeChain(
            chainId: "dest-chain",
            paraId: destParaId,
            name: "Destination Chain",
            asset: destAsset
        )

        return CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: ChainAsset(chain: originChain, asset: originAsset),
            destChainModel: destChain,
            amount: BigUInt(1_000_000),
            displayAmount: "1.00",
            originChainFee: BalanceViewModel(amount: "0.01", price: nil),
            destChainFee: BalanceViewModel(amount: "0.02", price: nil),
            destChainFeeDecimal: Decimal(string: "0.02") ?? .zero,
            recipientAddress: "recipient-address"
        )
    }

    private func makeChain(
        chainId: String,
        paraId: String,
        name: String,
        asset: AssetModel
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://\(chainId).example.org")!,
            name: "\(name) Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: paraId,
            name: name,
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://\(chainId).example.org/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class AccountInfoFetchingStub: AccountInfoFetchingProtocol {
    var fetchManyInvocations = 0
    var fetchManyResult: [ChainAsset: AccountInfo?] = [:]

    func fetch(
        for _: ChainAsset,
        accountId _: AccountId,
        completionBlock _: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        fatalError("Not used in this test")
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        completionBlock(fetchManyResult)
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        fetchManyInvocations += 1
        return fetchManyResult
    }

    func fetchByUniqKey(
        for _: [ChainAsset],
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

private final class AccountInfoRemoteServiceStub: AccountInfoRemoteService {
    var fetchInfosInvocations = 0
    var fetchInfosResult: [ChainAssetId: AccountInfo?] = [:]

    func fetchAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        fetchInfosInvocations += 1
        return fetchInfosResult
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        nil
    }
}

private final class StorageRequestPerformerStub: SSFStorageQueryKit.StorageRequestPerformer {
    var performMixInvocations = 0
    var lastMixRequests: [any MixStorageRequest] = []

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        chain _: ChainModel
    ) async throws -> T? { nil }

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<T>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func perform(
        _ requests: [any MixStorageRequest],
        chain _: ChainModel
    ) async throws -> [MixStorageResponse] {
        performMixInvocations += 1
        lastMixRequests = requests
        return []
    }
}
