import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class ClaimCrowdloanRewardsTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractorAndInitialViewModels() {
        let fixture = makeFixture()
        let view = ClaimCrowdloanRewardsViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertTrue(fixture.interactor.didEstimateFee)
        XCTAssertEqual(view.stakeAmountViewModel?.amountTitle.string, "stake")
        XCTAssertEqual(view.hintViewModel?.title?.string, "hint")
    }

    func testNavigationActions_whenTapped_thenDismissesOrSubmits() {
        let fixture = makeFixture()
        let view = ClaimCrowdloanRewardsViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.backButtonClicked()
        fixture.presenter.confirmButtonClicked()

        XCTAssertTrue(fixture.router.dismissedView === view)
        XCTAssertTrue(fixture.interactor.didSubmit)
    }

    func testInteractorCallbacks_whenDataArrives_thenUpdatesViewAndRoutesResults() {
        let fixture = makeFixture()
        let view = ClaimCrowdloanRewardsViewSpy()
        let expectedError = TestError.expected

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveBalanceLocks(nil)
        fixture.presenter.didReceiveTokenLocks(nil)
        fixture.presenter.didReceiveAccountInfo(accountInfo: nil)
        fixture.presenter.didReceiveFee(RuntimeDispatchInfo(feeValue: 1))
        fixture.presenter.didReceiveTxHash("0xhash")
        fixture.presenter.didReceiveTxError(expectedError)

        XCTAssertEqual(view.vestingViewModel?.amount, "vesting")
        XCTAssertEqual(view.balanceViewModel?.amount, "balance")
        XCTAssertNotNil(view.feeViewModel)
        XCTAssertEqual(fixture.router.completedTitle, "0xhash")
        XCTAssertTrue(fixture.router.completedView === view)
        XCTAssertTrue(fixture.router.presentedError is TestError)
    }

    func testApplyLocalization_whenCalled_thenRefreshesVestingViewModel() {
        let fixture = makeFixture()
        let view = ClaimCrowdloanRewardsViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.viewModelFactory.vestingAmount = "localized vesting"
        fixture.presenter.applyLocalization()

        XCTAssertEqual(view.vestingViewModel?.amount, "localized vesting")
    }

    private func makeFixture() -> ClaimCrowdloanRewardsFixture {
        let interactor = ClaimCrowdloanRewardsInteractorInputSpy()
        let router = ClaimCrowdloanRewardsRouterSpy()
        let viewModelFactory = ClaimCrowdloanRewardsViewModelFactorySpy()
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot"),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        )
        let presenter = ClaimCrowdloanRewardsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            logger: LoggerSpy(),
            chainAsset: chainAsset,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            viewModelFactory: viewModelFactory,
            wallet: AccountGenerator.generateMetaAccount(with: [])
        )

        return ClaimCrowdloanRewardsFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory
        )
    }
}

private struct ClaimCrowdloanRewardsFixture {
    let presenter: ClaimCrowdloanRewardsPresenter
    let interactor: ClaimCrowdloanRewardsInteractorInputSpy
    let router: ClaimCrowdloanRewardsRouterSpy
    let viewModelFactory: ClaimCrowdloanRewardsViewModelFactorySpy
}

private final class ClaimCrowdloanRewardsViewSpy: ClaimCrowdloanRewardsViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var vestingViewModel: BalanceViewModelProtocol?
    private(set) var balanceViewModel: BalanceViewModelProtocol?
    private(set) var stakeAmountViewModel: StakeAmountViewModel?
    private(set) var hintViewModel: DetailsTriangularedAttributedViewModel?

    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?) {
        self.feeViewModel = feeViewModel
    }

    func didReceiveVestingViewModel(_ viewModel: BalanceViewModelProtocol?) {
        vestingViewModel = viewModel
    }

    func didReceiveBalanceViewModel(_ viewModel: BalanceViewModelProtocol?) {
        balanceViewModel = viewModel
    }

    func didReceiveStakeAmountViewModel(_ stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>) {
        self.stakeAmountViewModel = stakeAmountViewModel.value(for: Locale.current)
    }

    func didReceiveHintViewModel(_ hintViewModel: DetailsTriangularedAttributedViewModel?) {
        self.hintViewModel = hintViewModel
    }
}

private final class ClaimCrowdloanRewardsInteractorInputSpy: ClaimCrowdloanRewardsInteractorInput {
    private(set) weak var output: ClaimCrowdloanRewardsInteractorOutput?
    private(set) var didEstimateFee = false
    private(set) var didSubmit = false

    func setup(with output: ClaimCrowdloanRewardsInteractorOutput) {
        self.output = output
    }

    func estimateFee() {
        didEstimateFee = true
    }

    func submit() {
        didSubmit = true
    }
}

private final class ClaimCrowdloanRewardsRouterSpy: ClaimCrowdloanRewardsRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var completedView: ControllerBackedProtocol?
    private(set) var completedTitle: String?
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset _: ChainAsset
    ) {
        completedView = view
        completedTitle = title
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class ClaimCrowdloanRewardsViewModelFactorySpy: ClaimCrowdloanRewardViewModelFactoryProtocol {
    var vestingAmount = "vesting"

    func buildBalanceViewModel(
        accountInfo _: AccountInfo?,
        priceData _: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in BalanceViewModel(amount: "balance", price: nil) }
    }

    func buildVestingViewModel(
        balanceLocks _: [LockProtocol]?,
        priceData _: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { [vestingAmount] _ in BalanceViewModel(amount: vestingAmount, price: nil) }
    }

    func createStakedAmountViewModel() -> LocalizableResource<StakeAmountViewModel> {
        LocalizableResource { _ in
            StakeAmountViewModel(
                amountTitle: NSAttributedString(string: "stake"),
                iconViewModel: nil,
                color: nil
            )
        }
    }

    func buildHintViewModel() -> LocalizableResource<DetailsTriangularedAttributedViewModel?> {
        LocalizableResource { _ in
            DetailsTriangularedAttributedViewModel(
                icon: UIImage(),
                title: NSAttributedString(string: "hint")
            )
        }
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

private enum TestError: Error {
    case expected
}
