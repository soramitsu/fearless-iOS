import RobinHood
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// Paging and provider paths of `WalletTransactionHistoryInteractor` that the recovery tests do not reach.
final class CovHTxHistoryInteractorTests: XCTestCase {
    private func makeInteractor(
        chain: ChainModel = CovHTxHistoryFixture.chain(),
        asset: AssetModel = CovHTxHistoryFixture.main,
        provider: SingleValueProvider<AssetTransactionPageData>? = nil
    ) -> (WalletTransactionHistoryInteractor, CovHTxHistoryRemote, CovHTxHistoryOutputSpy) {
        let remote = CovHTxHistoryRemote()
        let interactor = WalletTransactionHistoryInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: AccountGenerator.generateMetaAccount(),
            dependencyContainer: CovHTxHistoryDependencies(remote: remote, provider: provider),
            logger: Logger.shared,
            defaultFilter: WalletHistoryRequest(assets: [asset.id]),
            selectedFilter: WalletHistoryRequest(assets: [asset.id]),
            transactionsPerPage: 5,
            filters: [FilterSet(title: nil, items: [WalletTransactionHistoryFilter(type: .transfer, selected: true)])],
            eventCenter: EventCenter(),
            applicationHandler: ApplicationHandler()
        )
        addTeardownBlock {
            interactor.didReceiveDidEnterBackground(notification: Notification(name: UIApplication.didEnterBackgroundNotification))
        }
        return (interactor, remote, CovHTxHistoryOutputSpy())
    }

    private func page(_ ids: [String], next: String? = nil) -> AssetTransactionPageData {
        AssetTransactionPageData(
            transactions: ids.map { CovHTxHistoryFixture.transaction($0, type: TransactionType.outgoing.rawValue) },
            context: next.map { ["next": $0] }
        )
    }

    func testFilteredPagesLoadOnlyWhileAContinuationExists() {
        let (interactor, remote, output) = makeInteractor()
        XCTAssertFalse(interactor.loadNext(), "Nothing pages before the first answer")

        interactor.setup(with: output)
        XCTAssertEqual(output.filters.count, 1)
        XCTAssertEqual(remote.calls.count, 1, "Without a cache provider the first page is fetched at once")
        XCTAssertFalse(interactor.loadNext(), "The first filtered page is still loading")

        remote.complete(0, .success(page(["a", "b"], next: "2")))
        XCTAssertEqual(output.pageIds, [["a", "b"]])
        XCTAssertEqual(output.pages.last?.reload, true)

        XCTAssertTrue(interactor.loadNext())
        XCTAssertEqual(remote.calls.count, 2)
        XCTAssertEqual(remote.calls[1].pagination.context, ["next": "2"])
        XCTAssertTrue(interactor.loadNext(), "A following page is in flight")
        XCTAssertEqual(remote.calls.count, 2)

        remote.complete(1, .success(page(["c"])))
        XCTAssertEqual(output.pageIds.last, ["c"])
        XCTAssertEqual(output.pages.last?.reload, false)
        XCTAssertFalse(interactor.loadNext(), "No continuation, no further page")

        interactor.processNewTransaction(event: WalletNewTransactionInserted())
        XCTAssertEqual(remote.calls.count, 3)
        remote.complete(2, .failure(CovHTxHistoryError.unavailable))
        XCTAssertEqual(output.failures, [true])
        XCTAssertFalse(interactor.loadNext(), "A failed page waits for an explicit retry")
    }

    func testProviderCacheThenFreshPageThenNextPages() {
        let source = CovHTxHistoryPageSource(page: page(["fresh"], next: "p2"))
        let provider = SingleValueProvider(
            targetIdentifier: "cov-h-history-\(UUID().uuidString)",
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(CovHTxHistoryEmptyRepository())
        )
        let (interactor, remote, output) = makeInteractor(provider: provider)
        interactor.setup(with: output)

        CovHTxHistoryFixture.spin(timeout: 5) { output.pageIds.contains(["fresh"]) }
        // Let the provider's remaining refreshes land before paging on.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(output.pages.first?.page.transactions.isEmpty, true, "The empty cache is shown first")
        XCTAssertTrue(output.pageIds.contains(["fresh"]))
        XCTAssertTrue(output.pages.allSatisfy(\.reload))
        XCTAssertTrue(remote.calls.isEmpty, "The cache provider answers the first page")

        XCTAssertTrue(interactor.loadNext())
        XCTAssertEqual(remote.calls.last?.pagination.context, ["next": "p2"])
        XCTAssertTrue(interactor.loadNext(), "The next page is in flight")
        let calls = remote.calls.count
        remote.complete(calls - 1, .success(page(["older"])))
        XCTAssertEqual(output.pageIds.last, ["older"])
        XCTAssertEqual(output.pages.last?.reload, false)
    }

    func testProviderFailureBeforeTheCacheShowsAFailureAndForegroundRestartsTheTimer() {
        let (interactor, remote, output) = makeInteractor()
        interactor.presenter = output
        interactor.handleDataProvider(error: CovHTxHistoryError.unavailable)
        XCTAssertEqual(output.failures, [false])
        XCTAssertFalse(interactor.loadNext())

        interactor.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        interactor.reload()
        XCTAssertEqual(output.failures, [false])
        XCTAssertEqual(remote.calls.count, 1, "A reload without dependencies builds them and fetches the first page")
    }

    func testSoraTokensReadTheUtilityAssetsHistory() throws {
        let xor = CovHTxHistoryFixture.asset("cov-xor", symbol: "XOR", currencyId: "0x02", utility: true)
        let val = CovHTxHistoryFixture.asset("cov-val", symbol: "VAL", currencyId: "0x04")
        let sora = ChainModel(
            rank: nil,
            disabled: false,
            chainId: "cov-h-sora",
            paraId: nil,
            name: "SORA Mainnet",
            assets: [xor, val],
            xcm: nil,
            nodes: [],
            addressPrefix: 69,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        let (interactor, _, _) = makeInteractor(chain: sora, asset: val)
        XCTAssertEqual(interactor.getUtilityAsset(for: ChainAsset(chain: sora, asset: val))?.asset.id, "cov-xor")
        XCTAssertEqual(interactor.getUtilityAsset(for: ChainAsset(chain: sora, asset: xor))?.asset.id, "cov-xor")
        XCTAssertNil(interactor.getUtilityAsset(for: nil))
        let plain = ChainAsset(chain: CovHTxHistoryFixture.chain(), asset: CovHTxHistoryFixture.other)
        XCTAssertEqual(interactor.getUtilityAsset(for: plain)?.asset.id, CovHTxHistoryFixture.other.id)
    }
}

enum CovHTxHistoryError: Error {
    case unavailable
}
