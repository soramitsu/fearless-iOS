import Foundation
import RobinHood
import SSFModels
import XCTest
@testable import fearless

final class CovGAccountInfoAdapterTests: XCTestCase {
    func testDefaultSubscriptionDeliversInitialValueAndUnsubscribeStopsObservation() throws {
        let factory = CovGAdapterWalletFactory()
        let wallet = AccountGenerator.generateMetaAccount()
        let adapter = AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: factory, selectedMetaAccount: wallet)
        let handler = CovGAdapterHandler()
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        let accountId = Data(repeating: 3, count: 32)
        adapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: handler)
        waitUntil { handler.results.count == 1 && factory.observable.isObserved }
        XCTAssertNil(try handler.results[0].result.get())
        XCTAssertEqual(handler.results[0].accountId, accountId)
        XCTAssertEqual(handler.results[0].chainAsset, chainAsset)
        XCTAssertEqual(factory.requests.map(\.0), [accountId])

        adapter.unsubscribe(chainAsset: chainAsset)
        waitUntil { !factory.observable.isObserved }

        let replacement = AccountGenerator.generateMetaAccount()
        adapter.update(wallet: replacement)
        waitUntil { adapter.wallet.metaId == replacement.metaId }
    }

    func testResetDetachesHandlerAndRemovesEveryProviderObserver() throws {
        let factory = CovGAdapterWalletFactory()
        let wallet = AccountGenerator.generateMetaAccount()
        let adapter = AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: factory, selectedMetaAccount: wallet)
        let handler = CovGAdapterHandler()
        let chain = try CovGOperationFixtures.chain()
        let chainAsset = ChainAsset(chain: chain, asset: CovGOperationFixtures.asset)
        adapter.subscribe(chainsAssets: [chainAsset], handler: handler)
        waitUntil { handler.results.count == 1 && factory.observable.isObserved }
        let expected = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        XCTAssertEqual(factory.requests.map(\.0), [expected])
        XCTAssertEqual(handler.results.first?.accountId, expected)

        adapter.reset()
        waitUntil { !factory.observable.isObserved }
        adapter.handleAccountInfo(result: .success(nil), accountId: expected, chainAsset: chainAsset)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(handler.results.count, 1)
    }

    func testFactoryFailureLeavesNoSubscription() throws {
        let factory = CovGAdapterWalletFactory()
        factory.error = NSError(domain: "CovG.adapter", code: 68)
        let adapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: factory, selectedMetaAccount: AccountGenerator.generateMetaAccount()
        )
        let handler = CovGAdapterHandler()
        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        adapter.subscribe(chainAsset: chainAsset, accountId: Data(repeating: 4, count: 32), handler: handler, deliveryOn: .main, notifyJustWhenUpdated: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(factory.observable.isObserved)
        XCTAssertTrue(handler.results.isEmpty)
        adapter.unsubscribe(chainAsset: chainAsset)
        XCTAssertFalse(factory.observable.isObserved)
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

final class CovGAdapterHandler: AccountInfoSubscriptionAdapterHandler {
    struct Received {
        let result: Result<AccountInfo?, Error>
        let accountId: AccountId
        let chainAsset: ChainAsset
    }

    private(set) var results: [Received] = []

    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        results.append(Received(result: result, accountId: accountId, chainAsset: chainAsset))
    }
}

final class CovGAdapterWalletFactory: WalletLocalSubscriptionFactoryProtocol {
    let observable = CovGStreamObservable<AccountInfoStorageWrapper>()
    private lazy var provider = observable.provider(result: .success([]))
    let operationManager: OperationManagerProtocol = OperationManager()
    var processingQueue: DispatchQueue? {
        nil
    }

    var error: Error?
    private(set) var requests: [(AccountId, ChainAsset)] = []

    func getAccountProvider(for accountId: AccountId, chainAsset: ChainAsset) throws -> StreamableProvider<AccountInfoStorageWrapper> {
        if let error {
            throw error
        }
        requests.append((accountId, chainAsset))
        return provider
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        CovGHistoryRuntime()
    }
}
