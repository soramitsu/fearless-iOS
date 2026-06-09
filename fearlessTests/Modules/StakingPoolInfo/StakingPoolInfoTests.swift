import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class StakingPoolInfoTests: XCTestCase {
    func testDidLoad_whenStatusProvided_thenSetsUpInteractorAndPassesStatusToView() {
        let interactor = StakingPoolInfoInteractorInputSpy()
        let presenter = createPresenter(
            interactor: interactor,
            status: .validatorsNotSelected
        )
        let view = StakingPoolInfoViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        guard case .validatorsNotSelected? = view.receivedStatus else {
            return XCTFail("Expected validatorsNotSelected status")
        }
        XCTAssertEqual(interactor.fetchPoolNominationCallCount, 0)
    }

    func testWillAppear_whenViewModelNotLoaded_thenStartsLoading() {
        let presenter = createPresenter()
        let view = StakingPoolInfoViewSpy()

        presenter.willAppear(view: view)

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
    }

    func testRouteActions_whenTapped_thenForwardExpectedContext() {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let router = StakingPoolInfoRouterSpy()
        let presenter = createPresenter(
            router: router,
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = StakingPoolInfoViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapCloseButton()
        presenter.didTapValidators()
        presenter.nominatorDidTapped()
        presenter.bouncerDidTapped()
        presenter.rootDidTapped()

        XCTAssertTrue(router.dismissedView === view)
        XCTAssertTrue(router.validatorsView === view)
        XCTAssertEqual(router.validatorsChainAsset?.chain.chainId, chainAsset.chain.chainId)
        XCTAssertEqual(router.validatorsWallet?.metaId, wallet.metaId)
        XCTAssertEqual(router.walletManagementContextTags, [0, 1, 2])
        XCTAssertEqual(router.walletManagementOutputs.count, 3)
        XCTAssertTrue(router.walletManagementOutputs.compactMap { $0 }.allSatisfy { $0 === presenter })
    }

    func testCopyAddressTapped_whenCalled_thenPresentsCopiedStatus() {
        let router = StakingPoolInfoRouterSpy()
        let presenter = createPresenter(router: router)

        presenter.copyAddressTapped()

        XCTAssertTrue(router.presentedStatus is AddressCopiedEvent)
        XCTAssertEqual(router.presentStatusAnimated, true)
    }

    func testDidChangeStatus_whenModuleInputReceivesStatus_thenPassesStatusToView() {
        let presenter = createPresenter(status: nil)
        let view = StakingPoolInfoViewSpy()

        presenter.didLoad(view: view)
        presenter.didChange(status: .active(era: 42))

        guard case let .active(era)? = view.receivedStatus else {
            return XCTFail("Expected active status")
        }
        XCTAssertEqual(era, 42)
    }

    func testInteractorOutputs_whenErrorsArrive_thenLoggerReceivesMessages() {
        let logger = LoggerSpy()
        let presenter = createPresenter(logger: logger)

        presenter.didReceive(error: StakingPoolInfoTestError.failure)
        presenter.didReceive(activeEra: .failure(StakingPoolInfoTestError.failure))
        presenter.didReceive(palletIdResult: .failure(StakingPoolInfoTestError.failure))

        XCTAssertEqual(logger.errorMessages.count, 3)
    }

    private func createPresenter(
        interactor: StakingPoolInfoInteractorInput = StakingPoolInfoInteractorInputSpy(),
        router: StakingPoolInfoRouterInput = StakingPoolInfoRouterSpy(),
        viewModelFactory: StakingPoolInfoViewModelFactoryProtocol = StakingPoolInfoViewModelFactorySpy(),
        chainAsset: ChainAsset = ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("pool-asset", symbol: "dot"),
            chain: ChainModelGenerator.generate(count: 1).first!
        ),
        logger: LoggerProtocol? = LoggerSpy(),
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        status: NominationViewStatus? = nil
    ) -> StakingPoolInfoPresenter {
        StakingPoolInfoPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            logger: logger,
            wallet: wallet,
            status: status,
            localizationManager: LocalizationManager.shared
        )
    }

    private func makeChainAsset() -> ChainAsset {
        ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("pool-asset", symbol: "dot"),
            chain: ChainModelGenerator.generate(count: 1).first!
        )
    }
}

private final class StakingPoolInfoViewSpy: StakingPoolInfoViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var receivedViewModel: StakingPoolInfoViewModel?
    private(set) var receivedStatus: NominationViewStatus?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(viewModel: StakingPoolInfoViewModel) {
        receivedViewModel = viewModel
    }

    func didReceive(status: NominationViewStatus?) {
        receivedStatus = status
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class StakingPoolInfoInteractorInputSpy: StakingPoolInfoInteractorInput {
    private(set) weak var output: StakingPoolInfoInteractorOutput?
    private(set) var fetchPoolNominationCallCount = 0
    private(set) var poolStashAccountId: AccountId?
    private(set) var activeEra: EraIndex?

    func setup(with output: StakingPoolInfoInteractorOutput) {
        self.output = output
    }

    func fetchPoolNomination(poolStashAccountId: AccountId, activeEra: EraIndex) {
        fetchPoolNominationCallCount += 1
        self.poolStashAccountId = poolStashAccountId
        self.activeEra = activeEra
    }
}

private final class StakingPoolInfoRouterSpy: StakingPoolInfoRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var validatorsView: ControllerBackedProtocol?
    private(set) weak var updateRolesView: ControllerBackedProtocol?
    private(set) var validatorsChainAsset: ChainAsset?
    private(set) var validatorsWallet: MetaAccountModel?
    private(set) var updateRoles: StakingPoolRoles?
    private(set) var updatePoolId: String?
    private(set) var walletManagementContextTags: [Int] = []
    private(set) var walletManagementOutputs: [WalletsManagmentModuleOutput?] = []
    private(set) var presentedStatus: ApplicationStatusAlertEvent?
    private(set) var presentStatusAnimated: Bool?
    private(set) var dismissedStatus: ApplicationStatusAlertEvent?
    private(set) var dismissStatusAnimated: Bool?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        validatorsView = view
        validatorsChainAsset = chainAsset
        validatorsWallet = wallet
    }

    func showWalletManagment(
        contextTag: Int,
        from _: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        walletManagementContextTags.append(contextTag)
        walletManagementOutputs.append(moduleOutput)
    }

    func showUpdateRoles(
        roles: StakingPoolRoles,
        poolId: String,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        updateRoles = roles
        updatePoolId = poolId
        updateRolesView = view
    }

    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) {
        presentedStatus = viewModel
        presentStatusAnimated = animated
    }

    func dismissStatus(with viewModel: ApplicationStatusAlertEvent?, animated: Bool) {
        dismissedStatus = viewModel
        dismissStatusAnimated = animated
    }
}

private final class StakingPoolInfoViewModelFactorySpy: StakingPoolInfoViewModelFactoryProtocol {
    func buildViewModel(
        validators _: YourValidatorsModel,
        stakingPool _: StakingPool,
        locale _: Locale,
        roles _: StakingPoolRoles,
        wallet _: MetaAccountModel
    ) -> StakingPoolInfoViewModel {
        StakingPoolInfoViewModel(
            indexTitle: "1",
            name: "Pool",
            state: "open",
            stakedAmountViewModel: nil,
            membersCountTitle: "0",
            validatorsCountAttributedString: NSAttributedString(string: "0"),
            depositorName: nil,
            rootName: nil,
            nominatorName: nil,
            bouncerName: nil,
            rolesChanged: false,
            userIsRoot: false
        )
    }

    func buildStatus(
        poolInfo _: StakingPool,
        era _: EraIndex?,
        nomination _: Nomination?
    ) -> NominationViewStatus {
        .validatorsNotSelected
    }
}

private final class LoggerSpy: LoggerProtocol {
    private(set) var errorMessages: [String] = []

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}

    func error(message: String, file _: String, function _: String, line _: Int) {
        errorMessages.append(message)
    }

    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum StakingPoolInfoTestError: Error {
    case failure
}
