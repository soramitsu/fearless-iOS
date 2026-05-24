import XCTest
import SSFModels
@testable import fearless

final class ChainsIssuesCenterTests: XCTestCase {
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

    private func makeFixture(
        wallet: fearless.MetaAccountModel = AccountGenerator.generateMetaAccount(),
        missingAccountResults: [[ChainModel]]
    ) -> Fixture {
        let eventCenter = ChainsIssuesEventCenterSpy()
        let networkIssuesCenter = ChainsIssuesNetworkIssuesCenterSpy()
        let missingAccountFetcher = ChainsIssuesMissingAccountFetcherStub(results: missingAccountResults)
        let accountInfoFetcher = ChainsIssuesAccountInfoFetchingStub()
        let center = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: networkIssuesCenter,
            eventCenter: eventCenter,
            missingAccountHelper: missingAccountFetcher,
            accountInfoFetcher: accountInfoFetcher
        )

        return Fixture(
            center: center,
            eventCenter: eventCenter,
            missingAccountFetcher: missingAccountFetcher
        )
    }
}

private struct Fixture {
    let center: ChainsIssuesCenter
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

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        completionBlock(chainAsset, nil)
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: fearless.MetaAccountModel,
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
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        fetchManyResult
    }

    func fetchByUniqKey(
        for _: [ChainAsset],
        wallet _: fearless.MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
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
}
