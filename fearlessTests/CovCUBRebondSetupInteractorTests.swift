import XCTest
import BigInt
import RobinHood
import SSFModels
@testable import fearless

final class CovCUBRebondSetupOutputSpy: StakingRebondSetupInteractorOutputProtocol {
    private(set) var calls: [String] = []
    private(set) var controllers: [fearless.ChainAccountResponse?] = []
    private(set) var ledgers: [StakingLedger?] = []

    private static func succeeded<T>(_ result: Result<T, Error>) -> Bool {
        if case .success = result { return true }
        return false
    }

    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) {
        calls.append(Self.succeeded(result) ? "ledger" : "ledgerError")
        if case let .success(ledger) = result { ledgers.append(ledger) }
    }

    func didReceiveFee(result: Result<fearless.RuntimeDispatchInfo, Error>) {
        calls.append(Self.succeeded(result) ? "fee" : "feeError")
    }

    func didReceiveActiveEra(result: Result<ActiveEraInfo?, Error>) {
        calls.append(Self.succeeded(result) ? "era" : "eraError")
    }

    func didReceiveController(result: Result<fearless.ChainAccountResponse?, Error>) {
        calls.append(Self.succeeded(result) ? "controller" : "controllerError")
        if case let .success(controller) = result { controllers.append(controller) }
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) {
        calls.append(Self.succeeded(result) ? "stash" : "stashError")
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        calls.append(Self.succeeded(result) ? "account" : "accountError")
    }
}

final class CovCUBRebondSetupInteractorTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var kit: CovCUBStrategyKit!
    private var output: CovCUBRebondSetupOutputSpy!

    override func setUp() {
        super.setUp()
        chainAsset = CovCUBFixture.chainAsset()
        wallet = CovCUBFixture.wallet()
        kit = CovCUBStrategyKit(chainAsset: chainAsset, wallet: wallet)
        output = CovCUBRebondSetupOutputSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        kit = nil
        output = nil
        super.tearDown()
    }

    private func makeInteractor() -> StakingRebondSetupInteractor {
        let interactor = StakingRebondSetupInteractor(
            accountInfoSubscriptionAdapter: kit.accountInfo,
            stakingLocalSubscriptionFactory: kit.subscriptions,
            runtimeCodingService: kit.runtime,
            operationManager: kit.operations,
            feeProxy: kit.feeProxy,
            chainAsset: chainAsset,
            selectedAccount: wallet,
            connection: kit.engine,
            extrinsicService: kit.extrinsicService,
            accountRepository: kit.walletRepository,
            callFactory: kit.callFactory
        )
        interactor.presenter = output
        return interactor
    }

    func testSetupSubscribesAndEstimatesRebondFee() throws {
        let interactor = makeInteractor()

        interactor.setup()
        interactor.estimateFee()

        XCTAssertEqual(kit.subscriptions.stashRequests, [try CovCUBFixture.address(for: chainAsset, wallet: wallet)])
        XCTAssertTrue(kit.feeProxy.delegate === interactor)
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["rebond"])
        XCTAssertEqual(try CovCUBBuilderSpy.callNames(of: kit.feeProxy.closures.first), ["rebond"])
    }

    func testSubscriptionResultsReachPresenter() throws {
        let interactor = makeInteractor()
        let accountId = try CovCUBFixture.account(for: chainAsset, wallet: wallet).accountId

        interactor.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: chainAsset)
        interactor.handleLedgerInfo(result: .success(try CovCUBFixture.ledger(active: 2)), accountId: accountId, chainId: "c")
        interactor.handleActiveEra(result: .success(CovCUBFixture.activeEra(1)), chainId: "c")
        interactor.didReceiveFee(result: .failure(CovCUBTestError.failed), for: "id")

        XCTAssertEqual(output.calls, ["account", "ledger", "era", "feeError"])
        XCTAssertNotNil(output.ledgers.first ?? nil)
    }

    func testStashItemFailureAndAbsence() {
        let interactor = makeInteractor()

        interactor.handleStashItem(result: .failure(CovCUBTestError.failed), for: "addr")
        XCTAssertEqual(output.calls, ["stashError", "accountError", "ledgerError"])
        XCTAssertEqual(kit.accountInfo.resets, 0)

        interactor.handleStashItem(result: .success(nil), for: "addr")
        XCTAssertEqual(output.calls.suffix(3), ["stash", "ledger", "account"])
        XCTAssertEqual(kit.accountInfo.resets, 1)
        XCTAssertNil(output.ledgers.last ?? nil)
    }

    func testStashItemResolvesControllerAndEstimatesFee() throws {
        let interactor = makeInteractor()
        let account = try CovCUBFixture.account(for: chainAsset, wallet: wallet)
        let address = try CovCUBFixture.address(for: chainAsset, wallet: wallet)

        interactor.handleStashItem(result: .success(CovCUBFixture.stashItem(controller: address)), for: address)

        XCTAssertEqual(kit.accountInfo.subscribedAccounts, [account.accountId])
        CovCUBOperations.wait { output.calls.contains("controller") }
        XCTAssertEqual(output.controllers.last ?? nil, account)
        XCTAssertEqual(kit.feeProxy.reuseIdentifiers, ["rebond"])
    }
}

final class CovCUBStakingWireframesTests: XCTestCase {
    private var window: UIWindow?
    private var root: UIViewController!

    override func setUp() {
        super.setUp()
        root = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = root
        window.makeKeyAndVisible()
        self.window = window
    }

    override func tearDown() {
        root.dismiss(animated: false)
        window?.isHidden = true
        window = nil
        root = nil
        super.tearDown()
    }

    private func presentInNavigation(_ view: CovCUBViewSpy) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: view.controller)
        root.present(navigation, animated: false)
        return navigation
    }

    func testUnbondAndRebondSetupWireframesCloseThePresentedFlow() {
        let unbondView = CovCUBViewSpy()
        _ = presentInNavigation(unbondView)
        XCTAssertNotNil(root.presentedViewController)

        StakingUnbondSetupWireframe().close(view: unbondView)
        CovCUBOperations.wait { self.root.presentedViewController == nil }
        XCTAssertNil(root.presentedViewController)

        let rebondView = CovCUBViewSpy()
        _ = presentInNavigation(rebondView)
        StakingRebondSetupWireframe().close(view: rebondView)
        CovCUBOperations.wait { self.root.presentedViewController == nil }
        XCTAssertNil(root.presentedViewController)
    }

    func testRedeemConfirmationWireframeCompletesAndNotifies() {
        let view = CovCUBViewSpy()
        let navigation = presentInNavigation(view)
        var completions = 0
        let wireframe = StakingRedeemConfirmationWireframe(redeemCompletion: { completions += 1 })

        wireframe.complete(from: view)
        CovCUBOperations.wait { completions == 1 }

        XCTAssertEqual(completions, 1)
        XCTAssertFalse(root.presentedViewController === navigation)
    }

    func testRebondConfirmationWireframeDismissesTheFlow() {
        let view = CovCUBViewSpy()
        let navigation = presentInNavigation(view)

        StakingRebondConfirmationWireframe().complete(from: view)
        CovCUBOperations.wait { self.root.presentedViewController !== navigation }

        XCTAssertFalse(root.presentedViewController === navigation)
    }

    func testWireframesWithoutPresenterDoNothing() {
        let view = CovCUBViewSpy()
        var completions = 0

        StakingRedeemConfirmationWireframe(redeemCompletion: { completions += 1 }).complete(from: view)
        StakingRebondConfirmationWireframe().complete(from: view)
        StakingUnbondSetupWireframe().close(view: view)
        StakingRebondSetupWireframe().close(view: view)

        XCTAssertEqual(completions, 0)
        XCTAssertNil(view.controller.presentedViewController)
    }
}
