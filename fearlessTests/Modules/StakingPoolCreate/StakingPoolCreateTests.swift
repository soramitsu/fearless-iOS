import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class StakingPoolCreateTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenBootstrapsInteractorAndViewModels() {
        let fixture = makeFixture()
        let view = StakingPoolCreateViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertNotNil(view.viewModel)
        XCTAssertNotNil(view.amountInputViewModel)
        XCTAssertNil(view.feeViewModel)
        XCTAssertNotNil(view.nameViewModel)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 1)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.amount, .zero)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.poolName, "")
        XCTAssertNil(fixture.interactor.estimatedFeeCalls.last?.poolId)
    }

    func testAmountChanges_whenInputChanges_thenRefreshesFeeAndViewModels() {
        let fixture = makeFixture()
        let view = StakingPoolCreateViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: 10_000)))
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5)))
        fixture.presenter.selectAmountPercentage(0.5)
        fixture.presenter.updateAmount(2)

        XCTAssertNotNil(view.assetBalanceViewModel)
        XCTAssertNotNil(view.amountInputViewModel)
        XCTAssertNotNil(view.feeViewModel)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.count, 3)
        XCTAssertEqual(fixture.interactor.estimatedFeeCalls.last?.amount, BigUInt(200))
    }

    func testWalletRoleActions_whenTapped_thenRouteToWalletManagement() {
        let fixture = makeFixture()
        let view = StakingPoolCreateViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.nominatorDidTapped()
        fixture.presenter.bouncerDidTapped()
        fixture.presenter.rootDidTapped()
        fixture.presenter.backDidTapped()

        XCTAssertEqual(fixture.router.walletManagementCalls.map(\.contextTag), [0, 1, 2])
        XCTAssertTrue(fixture.router.walletManagementCalls.allSatisfy { $0.view === view })
        XCTAssertTrue(fixture.router.walletManagementCalls.allSatisfy { $0.output === fixture.presenter })
        XCTAssertTrue(fixture.router.dismissedView === view)
    }

    func testWalletManagementOutput_whenWalletSelected_thenUpdatesViewModelRoles() {
        let fixture = makeFixture()
        let view = StakingPoolCreateViewSpy()
        let nominator = AccountGenerator.generateMetaAccount().replacingName("Nominator")
        let bouncer = AccountGenerator.generateMetaAccount().replacingName("Bouncer")
        let root = AccountGenerator.generateMetaAccount().replacingName("Root")

        fixture.presenter.didLoad(view: view)
        fixture.presenter.selectedWallet(nominator, for: 0)
        fixture.presenter.selectedWallet(bouncer, for: 1)
        fixture.presenter.selectedWallet(root, for: 2)
        fixture.presenter.didReceiveLastPoolId(7)

        XCTAssertEqual(view.viewModel?.naminator, "Nominator")
        XCTAssertEqual(view.viewModel?.bouncer, "Bouncer")
        XCTAssertEqual(view.viewModel?.root, "Root")
        XCTAssertEqual(view.viewModel?.poolId, 8)
    }

    func testCreateDidTapped_whenInputsAreValid_thenRoutesToConfirm() {
        let fixture = makeFixture()
        let view = StakingPoolCreateViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveLastPoolId(41)
        fixture.presenter.didReceiveAccountInfo(result: .success(makeAccountInfo(free: 10_000)))
        fixture.presenter.didReceiveMinBond(1)
        fixture.presenter.didReceive(existentialDepositResult: .success(1))
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5)))
        fixture.presenter.updateAmount(2)
        view.nameViewModel?.inputHandler.changeValue(to: "Pool")

        fixture.presenter.createDidTapped()

        XCTAssertTrue(fixture.router.confirmView === view)
        XCTAssertEqual(fixture.router.confirmData?.poolId, 42)
        XCTAssertEqual(fixture.router.confirmData?.poolName, "Pool")
        XCTAssertEqual(fixture.router.confirmData?.amount, 2)
        XCTAssertEqual(fixture.router.confirmData?.root.name, "Wallet")
        XCTAssertEqual(fixture.router.confirmData?.nominator.name, "Wallet")
        XCTAssertEqual(fixture.router.confirmData?.bouncer.name, "Wallet")
    }

    private func makeFixture() -> StakingPoolCreateFixture {
        let interactor = StakingPoolCreateInteractorInputSpy()
        let router = StakingPoolCreateRouterSpy()
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("pool-asset", symbol: "dot", assetPresicion: 2),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0, assetPresicion: 2)
        )
        let presenter = StakingPoolCreatePresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            viewModelFactory: StakingPoolCreateViewModelFactory(),
            dataValidatingFactory: StakingDataValidatingFactory(
                presentable: router,
                balanceFactory: StubBalanceViewModelFactory()
            ),
            logger: LoggerSpy(),
            wallet: AccountGenerator.generateMetaAccount().replacingName("Wallet"),
            chainAsset: chainAsset,
            amount: nil
        )

        return StakingPoolCreateFixture(
            presenter: presenter,
            interactor: interactor,
            router: router
        )
    }

    private func makeAccountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
        )
    }
}

private struct StakingPoolCreateFixture {
    let presenter: StakingPoolCreatePresenter
    let interactor: StakingPoolCreateInteractorInputSpy
    let router: StakingPoolCreateRouterSpy
}

private final class StakingPoolCreateViewSpy: StakingPoolCreateViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var assetBalanceViewModel: AssetBalanceViewModelProtocol?
    private(set) var amountInputViewModel: IAmountInputViewModel?
    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var viewModel: StakingPoolCreateViewModel?
    private(set) var nameViewModel: InputViewModelProtocol?

    func didReceiveAssetBalanceViewModel(_ assetBalanceViewModel: AssetBalanceViewModelProtocol) {
        self.assetBalanceViewModel = assetBalanceViewModel
    }

    func didReceiveAmountInputViewModel(_ amountInputViewModel: IAmountInputViewModel) {
        self.amountInputViewModel = amountInputViewModel
    }

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) {
        self.feeViewModel = feeViewModel
    }

    func didReceiveViewModel(_ viewModel: StakingPoolCreateViewModel) {
        self.viewModel = viewModel
    }

    func didReceive(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel
    }
}

private final class StakingPoolCreateInteractorInputSpy: StakingPoolCreateInteractorInput {
    private(set) weak var output: StakingPoolCreateInteractorOutput?
    private(set) var estimatedFeeCalls: [(amount: BigUInt?, poolName: String, poolId: UInt32?)] = []

    func setup(with output: StakingPoolCreateInteractorOutput) {
        self.output = output
    }

    func estimateFee(amount: BigUInt?, poolName: String, poolId: UInt32?) {
        estimatedFeeCalls.append((amount, poolName, poolId))
    }
}

private final class StakingPoolCreateRouterSpy: StakingPoolCreateRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var confirmView: ControllerBackedProtocol?
    private(set) var confirmData: StakingPoolCreateData?
    private(set) var walletManagementCalls: [
        (contextTag: Int, view: ControllerBackedProtocol?, output: WalletsManagmentModuleOutput?)
    ] = []
    private(set) var presentedSheetViewModel: SheetAlertPresentableViewModel?
    private(set) var presentedMessages: [(message: String?, title: String)] = []
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func showWalletManagment(
        contextTag: Int,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        walletManagementCalls.append((contextTag, view, moduleOutput))
    }

    func showConfirm(
        from view: ControllerBackedProtocol?,
        with createData: StakingPoolCreateData
    ) {
        confirmView = view
        confirmData = createData
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedSheetViewModel = viewModel
    }

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append((message, title))
    }

    func presentInfo(
        message: String?,
        title: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessages.append((message, title))
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
