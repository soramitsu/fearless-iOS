import XCTest
import SSFModels
@testable import fearless

final class ChainsIssuesCenterTests: XCTestCase {
    func testCompositeAccountInfoFetching_whenFetchingMixedBatch_thenRoutesByEcosystem() async throws {
        let substrateChainAsset = makeSubstrateChainAsset()
        let ethereumChainAsset = makeEthereumChainAsset()
        let substrateFetcher = RoutingAccountInfoFetchingSpy()
        let ethereumFetcher = RoutingAccountInfoFetchingSpy()

        substrateFetcher.fetchManyResult = resultWithNilValue(for: substrateChainAsset)
        ethereumFetcher.fetchManyResult = resultWithNilValue(for: ethereumChainAsset)

        let compositeFetcher = CompositeAccountInfoFetching(
            substrateFetching: substrateFetcher,
            ethereumFetching: ethereumFetcher
        )

        let result = try await compositeFetcher.fetch(
            for: [substrateChainAsset, ethereumChainAsset],
            wallet: AccountGenerator.generateMetaAccount()
        )

        XCTAssertEqual(substrateFetcher.requestedBatchChainAssetIds, [[substrateChainAsset.chain.chainId]])
        XCTAssertEqual(ethereumFetcher.requestedBatchChainAssetIds, [[ethereumChainAsset.chain.chainId]])
        XCTAssertTrue(result.keys.contains(substrateChainAsset))
        XCTAssertTrue(result.keys.contains(ethereumChainAsset))
    }

    func testCompositeAccountInfoFetching_whenFetchingEthereumAsset_thenUsesEthereumFetcher() async throws {
        let ethereumChainAsset = makeEthereumChainAsset()
        let substrateFetcher = RoutingAccountInfoFetchingSpy()
        let ethereumFetcher = RoutingAccountInfoFetchingSpy()
        let compositeFetcher = CompositeAccountInfoFetching(
            substrateFetching: substrateFetcher,
            ethereumFetching: ethereumFetcher
        )

        _ = try await compositeFetcher.fetch(
            for: ethereumChainAsset,
            accountId: Data(repeating: 1, count: 20)
        )

        XCTAssertTrue(substrateFetcher.requestedSingleChainAssetIds.isEmpty)
        XCTAssertEqual(ethereumFetcher.requestedSingleChainAssetIds, [ethereumChainAsset.chain.chainId])
    }

    func testAddIssuesListener_whenGetExistingTrue_thenReturnsFetchedMissingAccounts() {
        let missingChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let fixture = makeFixture(missingAccountResults: [[missingChain]])
        let listener = ChainsIssuesCenterListenerSpy()

        fixture.center.addIssuesListener(listener, getExisting: true)

        XCTAssertEqual(listener.missingAccountChainIdsByNotification(), [[missingChain.chainId]])
    }

    func testSelectedAccountChanged_whenEventReceived_thenRefetchesMissingAccounts() {
        let initialChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let updatedChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 1)
        let wallet = AccountGenerator.generateMetaAccount()
        let nextWallet = AccountGenerator.generateMetaAccount()
        let fixture = makeFixture(
            wallet: wallet,
            missingAccountResults: [[initialChain], [updatedChain]]
        )
        let listener = ChainsIssuesCenterListenerSpy()

        fixture.center.addIssuesListener(listener, getExisting: true)
        fixture.eventCenter.notify(with: SelectedAccountChanged(account: nextWallet))

        XCTAssertEqual(fixture.missingAccountFetcher.requestedWalletIds, [wallet.metaId, nextWallet.metaId])
        XCTAssertEqual(
            listener.missingAccountChainIdsByNotification(),
            [[initialChain.chainId], [updatedChain.chainId]]
        )
    }

    func testRemoveIssuesListener_whenListenerRemoved_thenStopsSendingUpdates() {
        let initialChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let updatedChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 1)
        let fixture = makeFixture(missingAccountResults: [[initialChain], [updatedChain]])
        let listener = ChainsIssuesCenterListenerSpy()

        fixture.center.addIssuesListener(listener, getExisting: true)
        fixture.center.removeIssuesListener(listener)
        fixture.eventCenter.notify(with: SelectedAccountChanged(account: AccountGenerator.generateMetaAccount()))

        XCTAssertEqual(listener.missingAccountChainIdsByNotification(), [[initialChain.chainId]])
    }

    func testHandleChainsWithIssues_whenCachedPositiveBalanceExists_thenNotifiesNetworkIssue() throws {
        guard ChainsIssuesCenter.filtersNetworkIssuesByPositiveBalances else {
            throw XCTSkip("Positive-balance filtering is disabled in F_DEV builds")
        }

        let chainAsset = makeEthereumChainAsset()
        let accountInfoFetcher = ChainsIssuesAccountInfoFetchingStub()
        accountInfoFetcher.fetchManyResult = [chainAsset: AccountInfo(ethBalance: 1)]
        let fixture = makeFixture(
            missingAccountResults: [[]],
            accountInfoFetcher: accountInfoFetcher
        )
        let listener = ChainsIssuesCenterListenerSpy()

        fixture.center.addIssuesListener(listener, getExisting: true)
        fixture.networkIssuesCenter.notify(chains: [chainAsset.chain])

        XCTAssertEqual(accountInfoFetcher.requestedBatchChainAssetIds, [[chainAsset.chain.chainId]])
        XCTAssertEqual(listener.networkIssueChainIdsByNotification(), [[], [chainAsset.chain.chainId]])
    }

    func testHandleChainsWithIssues_whenCachedBalanceIsZero_thenSuppressesNetworkIssue() throws {
        guard ChainsIssuesCenter.filtersNetworkIssuesByPositiveBalances else {
            throw XCTSkip("Positive-balance filtering is disabled in F_DEV builds")
        }

        let chainAsset = makeEthereumChainAsset()
        let accountInfoFetcher = ChainsIssuesAccountInfoFetchingStub()
        accountInfoFetcher.fetchManyResult = [chainAsset: AccountInfo(ethBalance: 0)]
        let fixture = makeFixture(
            missingAccountResults: [[]],
            accountInfoFetcher: accountInfoFetcher
        )
        let listener = ChainsIssuesCenterListenerSpy()

        fixture.center.addIssuesListener(listener, getExisting: true)
        fixture.networkIssuesCenter.notify(chains: [chainAsset.chain])

        XCTAssertEqual(accountInfoFetcher.requestedBatchChainAssetIds, [[chainAsset.chain.chainId]])
        XCTAssertEqual(listener.networkIssueChainIdsByNotification(), [[], []])
    }

    private func makeFixture(
        wallet: fearless.MetaAccountModel = AccountGenerator.generateMetaAccount(),
        missingAccountResults: [[ChainModel]],
        accountInfoFetcher: ChainsIssuesAccountInfoFetchingStub = ChainsIssuesAccountInfoFetchingStub()
    ) -> Fixture {
        let eventCenter = ChainsIssuesEventCenterSpy()
        let networkIssuesCenter = ChainsIssuesNetworkIssuesCenterSpy()
        let missingAccountFetcher = ChainsIssuesMissingAccountFetcherStub(results: missingAccountResults)
        let center = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: networkIssuesCenter,
            eventCenter: eventCenter,
            missingAccountHelper: missingAccountFetcher,
            accountInfoFetcher: accountInfoFetcher
        )

        return Fixture(
            center: center,
            networkIssuesCenter: networkIssuesCenter,
            eventCenter: eventCenter,
            missingAccountFetcher: missingAccountFetcher
        )
    }
}

private func makeSubstrateChainAsset() -> ChainAsset {
    let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
    let asset = ChainModelGenerator.generateAssetWithId("substrate-asset", symbol: "SUB")
    return ChainModelGenerator.generateChainAsset(asset, chain: chain)
}

private func makeEthereumChainAsset() -> ChainAsset {
    let node = ChainNodeModel(
        url: URL(string: "https://node.example")!,
        name: "Node",
        apikey: nil
    )
    let asset = AssetModel(
        id: "native",
        name: "ETH",
        symbol: "ETH",
        precision: 18,
        isUtility: true,
        isNative: true,
        ethereumType: .normal
    )
    let chain = ChainModel(
        rank: nil,
        disabled: false,
        chainId: "ethereum-\(UUID().uuidString)",
        paraId: nil,
        name: "Ethereum",
        assets: [asset],
        xcm: nil,
        nodes: Set([node]),
        addressPrefix: 0,
        icon: nil,
        options: [.ethereum],
        iosMinAppVersion: nil,
        identityChain: nil
    )

    return ChainAsset(chain: chain, asset: asset)
}

private func resultWithNilValue(for chainAsset: ChainAsset) -> [ChainAsset: AccountInfo?] {
    var result: [ChainAsset: AccountInfo?] = [:]
    result.updateValue(nil, forKey: chainAsset)
    return result
}

private struct Fixture {
    let center: ChainsIssuesCenter
    let networkIssuesCenter: ChainsIssuesNetworkIssuesCenterSpy
    let eventCenter: ChainsIssuesEventCenterSpy
    let missingAccountFetcher: ChainsIssuesMissingAccountFetcherStub
}

private final class ChainsIssuesEventCenterSpy: EventCenterProtocol {
    private var observers: [EventVisitorProtocol] = []

    func notify(with event: EventProtocol) {
        observers.forEach { event.accept(visitor: $0) }
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        observers = observers.filter { $0 !== observer }
    }
}

private final class ChainsIssuesNetworkIssuesCenterSpy: NetworkIssuesCenterProtocol {
    private var listeners: [NetworkIssuesCenterListener] = []
    private(set) var forceNotifyCalls = 0

    func addIssuesListener(_ listener: NetworkIssuesCenterListener, getExisting _: Bool) {
        listeners.append(listener)
    }

    func removeIssuesListener(_ listener: NetworkIssuesCenterListener) {
        listeners = listeners.filter { $0 !== listener }
    }

    func forceNotify() {
        forceNotifyCalls += 1
    }

    func notify(chains: [ChainModel]) {
        listeners.forEach { $0.handleChainsWithIssues(chains) }
    }
}

private final class ChainsIssuesMissingAccountFetcherStub: MissingAccountFetcherProtocol {
    private var results: [[ChainModel]]
    private(set) var requestedWalletIds: [String] = []

    init(results: [[ChainModel]]) {
        self.results = results
    }

    func fetchMissingAccounts(
        for wallet: fearless.MetaAccountModel,
        complection: @escaping ([ChainModel]) -> Void
    ) {
        requestedWalletIds.append(wallet.metaId)
        complection(results.isEmpty ? [] : results.removeFirst())
    }
}

private final class ChainsIssuesAccountInfoFetchingStub: AccountInfoFetchingProtocol {
    var fetchManyResult: [ChainAsset: AccountInfo?] = [:]
    private(set) var requestedBatchChainAssetIds: [[ChainModel.Id]] = []

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        completionBlock(chainAsset, nil)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet _: fearless.MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        requestedBatchChainAssetIds.append(chainAssets.map(\.chain.chainId))
        completionBlock(fetchManyResult)
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        requestedBatchChainAssetIds.append(chainAssets.map(\.chain.chainId))
        return fetchManyResult
    }

    func fetchByUniqKey(
        for _: [ChainAsset],
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

private final class RoutingAccountInfoFetchingSpy: AccountInfoFetchingProtocol {
    var fetchManyResult: [ChainAsset: AccountInfo?] = [:]
    var fetchByUniqKeyResult: [ChainAssetKey: AccountInfo?] = [:]

    private(set) var requestedSingleChainAssetIds: [ChainModel.Id] = []
    private(set) var requestedBatchChainAssetIds: [[ChainModel.Id]] = []
    private(set) var requestedUniqKeyChainAssetIds: [[ChainModel.Id]] = []

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        requestedSingleChainAssetIds.append(chainAsset.chain.chainId)
        completionBlock(chainAsset, nil)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet _: fearless.MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        requestedBatchChainAssetIds.append(chainAssets.map(\.chain.chainId))
        completionBlock(fetchManyResult)
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        requestedSingleChainAssetIds.append(chainAsset.chain.chainId)
        return (chainAsset, nil)
    }

    func fetch(
        for chainAssets: [ChainAsset],
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        requestedBatchChainAssetIds.append(chainAssets.map(\.chain.chainId))
        return fetchManyResult
    }

    func fetchByUniqKey(
        for chainAssets: [ChainAsset],
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        requestedUniqKeyChainAssetIds.append(chainAssets.map(\.chain.chainId))
        return fetchByUniqKeyResult
    }
}

private final class ChainsIssuesCenterListenerSpy: ChainsIssuesCenterListener {
    private var receivedIssues: [[ChainIssue]] = []

    func handleChainsIssues(_ issues: [ChainIssue]) {
        receivedIssues.append(issues)
    }

    func missingAccountChainIdsByNotification() -> [[ChainModel.Id]] {
        receivedIssues.map { issues in
            issues.flatMap { issue -> [ChainModel.Id] in
                guard case let .missingAccount(chains) = issue else {
                    return []
                }

                return chains.map(\.chainId).sorted()
            }
        }
    }

    func networkIssueChainIdsByNotification() -> [[ChainModel.Id]] {
        receivedIssues.map { issues in
            issues.flatMap { issue -> [ChainModel.Id] in
                guard case let .network(chains) = issue else {
                    return []
                }

                return chains.map(\.chainId).sorted()
            }
        }
    }
}
