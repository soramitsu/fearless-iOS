import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class StakingPoolManagementTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let fixture = makeFixture()
        let view = StakingPoolManagementViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testPrimaryActions_whenTapped_thenRoutesToExpectedFlows() {
        let fixture = makeFixture()
        let view = StakingPoolManagementViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapCloseButton()
        fixture.presenter.didTapStakeMoreButton()
        fixture.presenter.didTapUnstakeButton()
        fixture.presenter.didTapRedeemButton()

        XCTAssertTrue(fixture.router.dismissedView === view)
        guard case .pool? = fixture.router.presentedStakeMoreFlow else {
            XCTFail("Expected pool stake-more flow")
            return
        }
        guard case .pool? = fixture.router.presentedUnbondFlow else {
            XCTFail("Expected pool unbond flow")
            return
        }
        guard case .pool? = fixture.router.presentedRedeemFlow else {
            XCTFail("Expected pool redeem flow")
            return
        }
        XCTAssertTrue(fixture.router.stakeMoreView === view)
        XCTAssertTrue(fixture.router.unbondView === view)
        XCTAssertTrue(fixture.router.redeemView === view)
    }

    func testOptionsAction_whenTapped_thenPresentsManagementOptions() {
        let fixture = makeFixture()
        let view = StakingPoolManagementViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapOptionsButton()

        XCTAssertEqual(fixture.router.presentedOptions?.count, 2)
        XCTAssertNotNil(fixture.router.optionsCallback)
        XCTAssertTrue(fixture.router.optionsView === view)
    }

    func testInteractorOutputs_whenSimpleDataArrives_thenUpdatesViewModels() {
        let fixture = makeFixture()
        let view = StakingPoolManagementViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceive(stakeInfo: nil)
        fixture.presenter.didReceive(stakingPool: nil)
        fixture.presenter.didReceive(pendingRewards: nil)

        XCTAssertNil(view.unstakingViewModel)
        XCTAssertNil(view.claimableViewModel)
        XCTAssertEqual(view.poolName, nil)
        XCTAssertEqual(view.managementViewModel?.stakeMoreButtonVisible, false)
        XCTAssertEqual(view.managementViewModel?.unstakeButtonVisible, false)
    }

    private func makeFixture() -> StakingPoolManagementFixture {
        let interactor = StakingPoolManagementInteractorInputSpy()
        let router = StakingPoolManagementRouterSpy()
        let chainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot"),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        )
        let presenter = StakingPoolManagementPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: AccountGenerator.generateMetaAccount(with: []),
            viewModelFactory: StakingPoolManagementViewModelFactorySpy(),
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            rewardCalculator: StakingPoolRewardCalculatorSpy(),
            status: nil,
            logger: LoggerSpy()
        )

        return StakingPoolManagementFixture(
            presenter: presenter,
            interactor: interactor,
            router: router
        )
    }
}

private struct StakingPoolManagementFixture {
    let presenter: StakingPoolManagementPresenter
    let interactor: StakingPoolManagementInteractorInputSpy
    let router: StakingPoolManagementRouterSpy
}

private final class StakingPoolManagementViewSpy: StakingPoolManagementViewInput {
    let controller = UIViewController()
    let isSetup = true

    private(set) var poolName: String?
    private(set) var balanceViewModel: BalanceViewModelProtocol?
    private(set) var unstakingViewModel: BalanceViewModelProtocol?
    private(set) var stakedAmountString: NSAttributedString?
    private(set) var redeemDelayViewModel: LocalizableResource<String>?
    private(set) var claimableViewModel: BalanceViewModelProtocol?
    private(set) var redeemableViewModel: BalanceViewModelProtocol?
    private(set) var managementViewModel: StakingPoolManagementViewModel?
    private(set) var selectValidatorVisible: Bool?

    func didReceive(poolName: String?) {
        self.poolName = poolName
    }

    func didReceive(balanceViewModel: BalanceViewModelProtocol?) {
        self.balanceViewModel = balanceViewModel
    }

    func didReceive(unstakingViewModel: BalanceViewModelProtocol?) {
        self.unstakingViewModel = unstakingViewModel
    }

    func didReceive(stakedAmountString: NSAttributedString) {
        self.stakedAmountString = stakedAmountString
    }

    func didReceive(redeemDelayViewModel: LocalizableResource<String>?) {
        self.redeemDelayViewModel = redeemDelayViewModel
    }

    func didReceive(claimableViewModel: BalanceViewModelProtocol?) {
        self.claimableViewModel = claimableViewModel
    }

    func didReceive(redeemableViewModel: BalanceViewModelProtocol?) {
        self.redeemableViewModel = redeemableViewModel
    }

    func didReceive(viewModel: StakingPoolManagementViewModel) {
        managementViewModel = viewModel
    }

    func didReceiveSelectValidator(visible: Bool) {
        selectValidatorVisible = visible
    }
}

private final class StakingPoolManagementInteractorInputSpy: StakingPoolManagementInteractorInput {
    private(set) weak var output: StakingPoolManagementInteractorOutput?
    private(set) var fetchedPoolBalanceAccountId: AccountId?
    private(set) var fetchedPoolNominationAccountId: AccountId?

    func setup(with output: StakingPoolManagementInteractorOutput) {
        self.output = output
    }

    func fetchPoolBalance(poolAccountId: AccountId) {
        fetchedPoolBalanceAccountId = poolAccountId
    }

    func fetchPoolNomination(poolStashAccountId: AccountId) {
        fetchedPoolNominationAccountId = poolStashAccountId
    }
}

private final class StakingPoolManagementRouterSpy: StakingPoolManagementRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var stakeMoreView: ControllerBackedProtocol?
    private(set) weak var unbondView: ControllerBackedProtocol?
    private(set) weak var redeemView: ControllerBackedProtocol?
    private(set) weak var optionsView: ControllerBackedProtocol?
    private(set) var presentedStakeMoreFlow: StakingBondMoreFlow?
    private(set) var presentedUnbondFlow: StakingUnbondSetupFlow?
    private(set) var presentedRedeemFlow: StakingRedeemConfirmationFlow?
    private(set) var presentedOptions: [TitleWithSubtitleViewModel]?
    private(set) var optionsCallback: ModalPickerSelectionCallback?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentStakeMoreFlow(
        flow: StakingBondMoreFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedStakeMoreFlow = flow
        stakeMoreView = view
    }

    func presentUnbondFlow(
        flow: StakingUnbondSetupFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedUnbondFlow = flow
        unbondView = view
    }

    func presentPoolInfo(
        stakingPool _: StakingPool,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        status _: NominationViewStatus?,
        from _: ControllerBackedProtocol?
    ) -> StakingPoolInfoModuleInput? {
        nil
    }

    func presentOptions(
        viewModels: [TitleWithSubtitleViewModel],
        callback: ModalPickerSelectionCallback?,
        from view: ControllerBackedProtocol?
    ) {
        presentedOptions = viewModels
        optionsCallback = callback
        optionsView = view
    }

    func presentClaim(
        rewardAmount _: Decimal,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {}

    func presentRedeemFlow(
        flow: StakingRedeemConfirmationFlow,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedRedeemFlow = flow
        redeemView = view
    }

    func proceedToSelectValidatorsStart(
        from _: ControllerBackedProtocol?,
        poolId _: UInt32,
        state _: InitiatedBonding,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {}
}

private final class StakingPoolManagementViewModelFactorySpy: StakingPoolManagementViewModelFactoryProtocol {
    func createStakedAmountViewModel(
        _: Decimal
    ) -> LocalizableResource<NSAttributedString> {
        LocalizableResource { _ in NSAttributedString(string: "staked") }
    }

    func buildUnstakeViewModel(
        stakingInfo _: StakingPoolMember?,
        activeEra _: EraIndex?,
        stakingDuration _: StakingDuration?
    ) -> LocalizableResource<String>? {
        nil
    }

    func buildViewModel(
        stakeInfo _: StakingPoolMember?,
        stakingPool _: StakingPool?,
        wallet _: MetaAccountModel
    ) -> StakingPoolManagementViewModel {
        StakingPoolManagementViewModel(
            stakeMoreButtonVisible: false,
            unstakeButtonVisible: false
        )
    }

    func buildOptionsPickerViewModels(locale _: Locale) -> [IconWithTitleViewModel] {
        []
    }
}

private final class StakingPoolRewardCalculatorSpy: StakinkPoolRewardCalculatorProtocol {
    func calculate(
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset,
        poolInfo _: StakingPool,
        poolAccountInfo _: AccountInfo,
        poolRewards _: StakingPoolRewards,
        stakeInfo _: StakingPoolMember,
        existentialDeposit _: BigUInt,
        priceData _: PriceData?,
        locale _: Locale
    ) -> PoolRewardCalculatorResult {
        PoolRewardCalculatorResult(
            totalRewardsDecimal: 0,
            totalRewards: BalanceViewModel(amount: "0", price: nil),
            totalStakeDecimal: 0,
            totalStake: BalanceViewModel(amount: "0", price: nil)
        )
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
