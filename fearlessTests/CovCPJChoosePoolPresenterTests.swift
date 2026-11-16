import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJChoosePoolViewDouble: StakingPoolJoinChoosePoolViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    var loadableContentView: UIView { controller.view }
    var shouldDisableInteractionWhenLoading: Bool { true }

    private(set) var cellViewModels: [[StakingPoolListTableCellModel]] = []
    private(set) var locales: [Locale] = []
    private(set) var events: [String] = []

    func didReceive(cellViewModels: [StakingPoolListTableCellModel]) { self.cellViewModels.append(cellViewModels) }
    func didReceive(locale: Locale) { locales.append(locale) }
    func didStartLoading() { events.append("start") }
    func didStopLoading() { events.append("stop") }
}

final class CovCPJChoosePoolInteractorDouble: StakingPoolJoinChoosePoolInteractorInput {
    private(set) weak var output: StakingPoolJoinChoosePoolInteractorOutput?

    func setup(with output: StakingPoolJoinChoosePoolInteractorOutput) { self.output = output }
}

final class CovCPJChoosePoolRouterDouble: CovCPJPresentableRecorder, StakingPoolJoinChoosePoolRouterInput {
    private(set) var confirmedPoolIds: [String] = []
    private(set) var confirmedAmounts: [Decimal] = []
    private(set) var options: [[SortPickerTableViewCellModel]] = []
    private(set) var callbacks: [ModalPickerSelectionCallback] = []
    private(set) var infoPoolIds: [String] = []

    func presentConfirm(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        inputAmount: Decimal,
        selectedPool: StakingPool
    ) {
        confirmedPoolIds.append(selectedPool.id)
        confirmedAmounts.append(inputAmount)
    }

    func presentOptions(
        options: [SortPickerTableViewCellModel],
        callback: ModalPickerSelectionCallback?,
        from _: ControllerBackedProtocol?
    ) {
        self.options.append(options)
        if let callback = callback {
            callbacks.append(callback)
        }
    }

    func presentPoolInfo(
        stakingPool: StakingPool,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        infoPoolIds.append(stakingPool.id)
    }
}

final class CovCPJChoosePoolPresenterTests: XCTestCase {
    private var view: CovCPJChoosePoolViewDouble!
    private var interactor: CovCPJChoosePoolInteractorDouble!
    private var router: CovCPJChoosePoolRouterDouble!
    private var presenter: StakingPoolJoinChoosePoolPresenter!

    override func setUpWithError() throws {
        try super.setUpWithError()
        view = CovCPJChoosePoolViewDouble()
        interactor = CovCPJChoosePoolInteractorDouble()
        router = CovCPJChoosePoolRouterDouble()
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10, symbol: "dot")

        presenter = StakingPoolJoinChoosePoolPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovCPJFixtures.localizationManager(),
            viewModelFactory: StakingPoolJoinChoosePoolViewModelFactory(
                chainAsset: chainAsset,
                assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
            ),
            inputAmount: 15,
            chainAsset: chainAsset,
            wallet: CovCPJFixtures.wallet(),
            filterFactory: TitleSwitchTableViewCellModelFactory()
        )
        presenter.didLoad(view: view)
    }

    override func tearDown() {
        presenter = nil
        view = nil
        interactor = nil
        router = nil
        super.tearDown()
    }

    private func pools() -> [StakingPool] {
        [
            CovCPJFixtures.pool(id: "1", name: "Big", points: 900_000_000_000, members: 2),
            CovCPJFixtures.pool(id: "2", name: "Crowded", points: 100_000_000_000, members: 40)
        ]
    }

    func testDidLoadSetsUpAndStartsLoading() {
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.locales.count, 1)
        XCTAssertEqual(view.events, ["start"])
    }

    func testPoolsAreShownAndLoadingStops() {
        presenter.didReceivePools(pools())

        XCTAssertEqual(view.cellViewModels.last?.map(\.poolId), ["1", "2"])
        XCTAssertEqual(view.events, ["start", "stop"])
    }

    func testErrorIsPresented() {
        presenter.didReceiveError(CovCPJTestError.failed)

        XCTAssertEqual(router.presentedErrors.count, 1)
    }

    func testContinueRequiresSelection() throws {
        presenter.didReceivePools(pools())

        presenter.didTapContinueButton()
        XCTAssertTrue(router.confirmedPoolIds.isEmpty)

        let crowded = try XCTUnwrap(view.cellViewModels.last?.last)
        crowded.didTapCell()
        XCTAssertEqual(view.cellViewModels.last?.map(\.isSelected), [false, true])

        presenter.didTapContinueButton()
        XCTAssertEqual(router.confirmedPoolIds, ["2"])
        XCTAssertEqual(router.confirmedAmounts, [15])
    }

    func testOptionsChangeSorting() throws {
        presenter.didReceivePools(pools())

        presenter.didTapOptionsButton()

        let options = try XCTUnwrap(router.options.first)
        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(
            options.first?.title,
            R.string.localizable.stakingValidatorTotalStakeToken("DOT", preferredLanguages: CovCPJFixtures.languages)
        )
        XCTAssertEqual(options.map(\.switchIsOn), [false, true])

        router.callbacks.first?(0)
        XCTAssertEqual(view.cellViewModels.last?.map(\.poolId), ["2", "1"])

        router.callbacks.first?(1)
        XCTAssertEqual(view.cellViewModels.last?.map(\.poolId), ["1", "2"])
    }

    func testPoolInfoOnlyForKnownPools() throws {
        presenter.didReceivePools(pools())

        let big = try XCTUnwrap(view.cellViewModels.last?.first)
        big.didTapInfoButton()
        presenter.showPoolInfo(poolId: "missing")

        XCTAssertEqual(router.infoPoolIds, ["1"])
    }

    func testBackAndLocalization() {
        presenter.didTapBackButton()
        presenter.applyLocalization()

        XCTAssertEqual(router.dismissCount, 1)
        XCTAssertEqual(view.locales.count, 2)
    }
}
