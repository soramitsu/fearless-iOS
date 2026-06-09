import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class LiquidityPoolsOverviewTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractor() {
        let fixture = makeFixture()
        let view = LiquidityPoolsOverviewViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testBackButton_whenTapped_thenDismissesAndResetsChildTasks() {
        let fixture = makeFixture()
        let view = LiquidityPoolsOverviewViewSpy()
        let availableInput = LiquidityPoolsListModuleInputSpy()
        let userInput = LiquidityPoolsListModuleInputSpy()
        fixture.presenter.availablePoolsInput = availableInput
        fixture.presenter.userPoolsInput = userInput

        fixture.presenter.didLoad(view: view)
        fixture.presenter.backButtonClicked()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertEqual(availableInput.resetTasksCallCount, 1)
        XCTAssertEqual(userInput.resetTasksCallCount, 1)
    }

    func testRefresh_whenTriggered_thenRefreshesBothChildLists() {
        let fixture = makeFixture()
        let availableInput = LiquidityPoolsListModuleInputSpy()
        let userInput = LiquidityPoolsListModuleInputSpy()
        fixture.presenter.availablePoolsInput = availableInput
        fixture.presenter.userPoolsInput = userInput

        fixture.presenter.handleRefreshControlEvent()
        fixture.presenter.didReceiveTransactionFinalizedEvent()

        XCTAssertEqual(availableInput.refreshDataCallCount, 2)
        XCTAssertEqual(userInput.refreshDataCallCount, 2)
    }

    func testListOutputEvents_whenReceived_thenRoutesAndUpdatesView() {
        let fixture = makeFixture()
        let view = LiquidityPoolsOverviewViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapMoreAvailablePools()
        fixture.presenter.didTapMoreUserPools()
        fixture.presenter.shouldShowUserPools(false)
        fixture.presenter.didReceiveUserPoolCount(3)

        XCTAssertTrue(fixture.router.availablePoolsView === view)
        XCTAssertTrue(fixture.router.userPoolsView === view)
        XCTAssertEqual(fixture.router.availablePoolsChain?.chainId, fixture.chain.chainId)
        XCTAssertEqual(fixture.router.userPoolsWallet?.metaId, fixture.wallet.metaId)
        XCTAssertEqual(view.userPoolsVisible, false)
        XCTAssertEqual(view.userPoolsCount, 3)
    }

    func testSubmittedTransaction_whenReceived_thenSubscribesInteractor() {
        let fixture = makeFixture()

        fixture.presenter.didSubmitTransaction(transactionHash: "0xhash")

        XCTAssertEqual(fixture.interactor.subscribedHashes, ["0xhash"])
    }

    private func makeFixture() -> LiquidityPoolsOverviewFixture {
        let interactor = LiquidityPoolsOverviewInteractorInputSpy()
        let router = LiquidityPoolsOverviewRouterSpy()
        let chain = makeChain()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let presenter = LiquidityPoolsOverviewPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            chain: chain,
            wallet: wallet
        )

        return LiquidityPoolsOverviewFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            chain: chain,
            wallet: wallet
        )
    }

    private func makeChain() -> ChainModel {
        let node = ChainNodeModel(url: URL(string: "wss://sora.example")!, name: "Sora", apikey: nil)
        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "sora-chain",
            paraId: nil,
            name: "Sora Mainnet",
            assets: [],
            xcm: nil,
            nodes: [node],
            addressPrefix: 69,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private struct LiquidityPoolsOverviewFixture {
    let presenter: LiquidityPoolsOverviewPresenter
    let interactor: LiquidityPoolsOverviewInteractorInputSpy
    let router: LiquidityPoolsOverviewRouterSpy
    let chain: ChainModel
    let wallet: MetaAccountModel
}

private final class LiquidityPoolsOverviewViewSpy: LiquidityPoolsOverviewViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var userPoolsVisible: Bool?
    private(set) var userPoolsCount: Int?

    func changeUserPoolsVisibility(visible: Bool) {
        userPoolsVisible = visible
    }

    func didReceiveUserPoolsCount(count: Int) {
        userPoolsCount = count
    }
}

private final class LiquidityPoolsOverviewInteractorInputSpy: LiquidityPoolsOverviewInteractorInput {
    private(set) weak var output: LiquidityPoolsOverviewInteractorOutput?
    private(set) var subscribedHashes: [String] = []

    func setup(with output: LiquidityPoolsOverviewInteractorOutput) {
        self.output = output
    }

    func subscribe(transactionHash: String) {
        subscribedHashes.append(transactionHash)
    }
}

private final class LiquidityPoolsOverviewRouterSpy: LiquidityPoolsOverviewRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var availablePoolsView: ControllerBackedProtocol?
    private(set) weak var userPoolsView: ControllerBackedProtocol?
    private(set) var availablePoolsChain: ChainModel?
    private(set) var userPoolsWallet: MetaAccountModel?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showAllAvailablePools(
        chain: ChainModel,
        wallet _: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput _: LiquidityPoolsListModuleOutput?
    ) {
        availablePoolsChain = chain
        availablePoolsView = view
    }

    func showAllUserPools(
        chain _: ChainModel,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput _: LiquidityPoolsListModuleOutput?
    ) {
        userPoolsWallet = wallet
        userPoolsView = view
    }
}

private final class LiquidityPoolsListModuleInputSpy: LiquidityPoolsListModuleInput {
    private(set) var resetTasksCallCount = 0
    private(set) var refreshDataCallCount = 0

    func resetTasks() {
        resetTasksCallCount += 1
    }

    func refreshData() {
        refreshDataCallCount += 1
    }
}
