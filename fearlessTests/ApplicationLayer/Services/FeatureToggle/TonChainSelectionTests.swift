import XCTest
@testable import fearless
import SSFModels
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
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
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
