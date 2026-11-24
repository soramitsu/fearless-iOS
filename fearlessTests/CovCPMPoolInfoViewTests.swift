import XCTest
import SoraFoundation
@testable import fearless

final class CovCPMPoolInfoViewOutputSpy: StakingPoolInfoViewOutput {
    private(set) var didLoadCount = 0
    private(set) var willAppearCount = 0
    private(set) var closeCount = 0
    private(set) var validatorsCount = 0
    private(set) var nominatorCount = 0
    private(set) var bouncerCount = 0
    private(set) var rootCount = 0
    private(set) var saveRolesCount = 0
    private(set) var copyCount = 0

    func didLoad(view _: StakingPoolInfoViewInput) { didLoadCount += 1 }
    func didTapCloseButton() { closeCount += 1 }
    func didTapValidators() { validatorsCount += 1 }
    func willAppear(view _: StakingPoolInfoViewInput) { willAppearCount += 1 }
    func nominatorDidTapped() { nominatorCount += 1 }
    func bouncerDidTapped() { bouncerCount += 1 }
    func rootDidTapped() { rootCount += 1 }
    func saveRolesDidTapped() { saveRolesCount += 1 }
    func copyAddressTapped() { copyCount += 1 }
}

enum CovCPMPoolInfoViewFixtures {
    static let languages = ["en"]

    static func viewModel(rolesChanged: Bool, userIsRoot: Bool) -> StakingPoolInfoViewModel {
        StakingPoolInfoViewModel(
            indexTitle: "42",
            name: "Pool name",
            state: "Open",
            stakedAmountViewModel: BalanceViewModel(amount: "10 DOT", price: "$50"),
            membersCountTitle: "7",
            validatorsCountAttributedString: NSAttributedString(string: "3"),
            depositorName: "depositor-address",
            rootName: "root-address",
            nominatorName: "nominator-address",
            bouncerName: "bouncer-address",
            rolesChanged: rolesChanged,
            userIsRoot: userIsRoot
        )
    }

    static func countdown(activeEra: EraIndex) -> EraCountdown {
        EraCountdown(
            activeEra: activeEra,
            currentEra: activeEra,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 1,
            currentSessionIndex: 2,
            currentSlot: 100,
            genesisSlot: 1,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }

    static func findSubview(withIdentifier identifier: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == identifier {
            return view
        }
        for subview in view.subviews {
            if let found = findSubview(withIdentifier: identifier, in: subview) {
                return found
            }
        }
        return nil
    }
}

final class CovCPMPoolInfoViewLayoutTests: XCTestCase {
    private let languages = CovCPMPoolInfoViewFixtures.languages

    private func makeLayout() -> StakingPoolInfoViewLayout {
        let view = StakingPoolInfoViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = Locale(identifier: "en")
        view.layoutIfNeeded()
        return view
    }

    func testLocalizationSetsTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.indexView.titleLabel.text, R.string.localizable.indexCommon(preferredLanguages: languages))
        XCTAssertEqual(view.nameView.titleLabel.text, R.string.localizable.usernameSetupChooseTitle(preferredLanguages: languages))
        XCTAssertEqual(view.stateView.titleLabel.text, R.string.localizable.stateCommon(preferredLanguages: languages))
        XCTAssertEqual(
            view.stakedView.titleLabel.text,
            R.string.localizable.stakingMainStakeBalanceStaked(preferredLanguages: languages)
        )
        XCTAssertEqual(view.membersCountView.titleLabel.text, R.string.localizable.membersCommon(preferredLanguages: languages))
        XCTAssertEqual(
            view.validatorsView.titleLabel.text,
            R.string.localizable.stakingRewardDetailsValidator(preferredLanguages: languages)
        )
        XCTAssertEqual(view.roleDepositorView.title, R.string.localizable.poolStakingDepositor(preferredLanguages: languages))
        XCTAssertEqual(view.roleRootView.title, R.string.localizable.poolStakingRoot(preferredLanguages: languages))
        XCTAssertEqual(view.roleNominatorView.title, R.string.localizable.poolStakingNominator(preferredLanguages: languages))
        XCTAssertEqual(view.roleBouncerView.title, R.string.localizable.poolStakingBouncer(preferredLanguages: languages))
        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.stakingPoolInfoTitle(preferredLanguages: languages))
        XCTAssertEqual(view.rolesTitleLabel.text, R.string.localizable.rolesCommon(preferredLanguages: languages))
        XCTAssertEqual(view.saveRolesButton.imageWithTitleView?.title, R.string.localizable.commonSave(preferredLanguages: languages))
        XCTAssertTrue(view.saveRolesButton.isHidden)
        XCTAssertEqual(view.roleViews.count, 4)
    }

    func testBindViewModelForRootUserWithChangedRoles() {
        let view = makeLayout()

        view.bind(viewModel: CovCPMPoolInfoViewFixtures.viewModel(rolesChanged: true, userIsRoot: true))

        XCTAssertEqual(view.indexView.valueLabel.text, "42")
        XCTAssertEqual(view.nameView.valueLabel.text, "Pool name")
        XCTAssertEqual(view.stateView.valueLabel.text, "Open")
        XCTAssertEqual(view.stakedView.valueTop.text, "10 DOT")
        XCTAssertEqual(view.stakedView.valueBottom.text, "$50")
        XCTAssertEqual(view.membersCountView.valueLabel.text, "7")
        XCTAssertEqual(view.validatorsView.valueLabel.attributedText?.string, "3")
        XCTAssertEqual(view.roleDepositorView.subtitle, "depositor-address")
        XCTAssertEqual(view.roleRootView.subtitle, "root-address")
        XCTAssertEqual(view.roleNominatorView.subtitle, "nominator-address")
        XCTAssertEqual(view.roleBouncerView.subtitle, "bouncer-address")
        XCTAssertFalse(view.saveRolesButton.isHidden)

        for roleView in [view.roleRootView, view.roleNominatorView, view.roleBouncerView] {
            XCTAssertFalse(roleView.actionView.isHidden)
            XCTAssertTrue(roleView.isUserInteractionEnabled)
            XCTAssertNotEqual(roleView.triangularedBackgroundView?.fillColor, view.roleDepositorView.triangularedBackgroundView?.fillColor)
        }
        XCTAssertTrue(view.roleDepositorView.actionView.isHidden)
    }

    func testBindViewModelForNonRootUserMakesRolesCopiable() {
        let view = makeLayout()

        view.bind(viewModel: CovCPMPoolInfoViewFixtures.viewModel(rolesChanged: false, userIsRoot: false))

        XCTAssertTrue(view.saveRolesButton.isHidden)
        for roleView in view.roleViews {
            XCTAssertFalse(roleView.actionView.isHidden)
            XCTAssertTrue(roleView.isUserInteractionEnabled)
            XCTAssertNotNil(roleView.actionView.image)
        }
    }

    func testBindNilStatusHidesStatusView() {
        let view = makeLayout()

        view.bind(status: nil)

        XCTAssertTrue(view.statusView.isHidden)
    }

    func testBindActiveStatus() {
        let view = makeLayout()
        view.bind(status: nil)

        view.bind(status: .active(era: 5))

        XCTAssertFalse(view.statusView.isHidden)
        XCTAssertEqual(
            view.statusView.titleView.titleLabel.text,
            R.string.localizable.stakingNominatorStatusActive(preferredLanguages: languages).uppercased()
        )
        XCTAssertEqual(
            view.statusView.valueView.detailsLabel.text,
            R.string.localizable.stakingEraTitle("5", preferredLanguages: languages).uppercased()
        )
    }

    func testBindInactiveStatus() {
        let view = makeLayout()

        view.bind(status: .inactive(era: 9))

        XCTAssertFalse(view.statusView.isHidden)
        XCTAssertEqual(
            view.statusView.titleView.titleLabel.text,
            R.string.localizable.stakingNominatorStatusInactive(preferredLanguages: languages).uppercased()
        )
        XCTAssertEqual(
            view.statusView.valueView.detailsLabel.text,
            R.string.localizable.stakingEraTitle("9", preferredLanguages: languages).uppercased()
        )
    }

    func testBindWaitingStatusWithoutCountdownClearsDetails() {
        let view = makeLayout()
        view.statusView.valueView.detailsLabel.text = "previous"

        view.bind(status: .waiting(eraCountdown: nil, nominationEra: 3))

        XCTAssertFalse(view.statusView.isHidden)
        XCTAssertEqual(
            view.statusView.titleView.titleLabel.text,
            R.string.localizable.stakingNominatorStatusWaiting(preferredLanguages: languages).uppercased()
        )
        XCTAssertEqual(view.statusView.valueView.detailsLabel.text, "")
    }

    func testBindWaitingStatusWithElapsedCountdownKeepsDetails() {
        let view = makeLayout()
        view.statusView.valueView.detailsLabel.text = "previous"

        view.bind(status: .waiting(eraCountdown: CovCPMPoolInfoViewFixtures.countdown(activeEra: 100), nominationEra: 3))

        XCTAssertFalse(view.statusView.isHidden)
        XCTAssertEqual(
            view.statusView.titleView.titleLabel.text,
            R.string.localizable.stakingNominatorStatusWaiting(preferredLanguages: languages).uppercased()
        )
        XCTAssertEqual(view.statusView.valueView.detailsLabel.text, "previous")
    }

    func testBindValidatorsNotSelectedStatus() {
        let view = makeLayout()

        view.bind(status: .validatorsNotSelected)

        XCTAssertFalse(view.statusView.isHidden)
        XCTAssertEqual(
            view.statusView.titleView.titleLabel.text,
            R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: languages).uppercased()
        )
    }

    func testBindUndefinedStatusKeepsStatusHidden() {
        let view = makeLayout()
        view.bind(status: nil)

        view.bind(status: .undefined)

        XCTAssertTrue(view.statusView.isHidden)
    }
}

final class CovCPMPoolInfoViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController(output: CovCPMPoolInfoViewOutputSpy) throws -> StakingPoolInfoViewController {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingPoolInfoViewController(output: output, localizationManager: manager)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        controller.loadViewIfNeeded()
        return controller
    }

    func testLoadingNotifiesOutputAndAppliesLocale() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        XCTAssertEqual(output.didLoadCount, 1)
        XCTAssertEqual(controller.rootView.locale.identifier, "en")

        controller.viewWillAppear(false)
        XCTAssertGreaterThanOrEqual(output.willAppearCount, 1)

        controller.applyLocalization()
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.stakingPoolInfoTitle(preferredLanguages: ["en"])
        )
    }

    func testCloseButtonAndValidatorsActionsReachOutput() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.closeCount, 1)

        XCTAssertEqual(controller.rootView.validatorsView.gestureRecognizers?.count, 1)
        controller.perform(NSSelectorFromString("validatorsClicked"))
        XCTAssertEqual(output.validatorsCount, 1)

        controller.rootView.roleDepositorView.onCopied?()
        controller.rootView.roleBouncerView.onCopied?()
        XCTAssertEqual(output.copyCount, 2)
    }

    func testRootUserViewModelEnablesRoleActions() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        controller.didReceive(viewModel: CovCPMPoolInfoViewFixtures.viewModel(rolesChanged: true, userIsRoot: true))

        XCTAssertEqual(controller.rootView.indexView.valueLabel.text, "42")
        XCTAssertFalse(controller.rootView.saveRolesButton.isHidden)

        controller.rootView.roleNominatorView.sendActions(for: .touchUpInside)
        controller.rootView.roleBouncerView.sendActions(for: .touchUpInside)
        controller.rootView.roleRootView.sendActions(for: .touchUpInside)
        controller.rootView.saveRolesButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.nominatorCount, 1)
        XCTAssertEqual(output.bouncerCount, 1)
        XCTAssertEqual(output.rootCount, 1)
        XCTAssertEqual(output.saveRolesCount, 1)
    }

    func testNonRootViewModelDoesNotWireSaveAction() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        controller.didReceive(viewModel: CovCPMPoolInfoViewFixtures.viewModel(rolesChanged: true, userIsRoot: false))
        controller.rootView.saveRolesButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.saveRolesCount, 0)
        XCTAssertEqual(controller.rootView.roleNominatorView.subtitle, "nominator-address")
    }

    func testStatusInputBindsRootView() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        controller.didReceive(status: .active(era: 12))
        XCTAssertFalse(controller.rootView.statusView.isHidden)
        XCTAssertEqual(
            controller.rootView.statusView.valueView.detailsLabel.text,
            R.string.localizable.stakingEraTitle("12", preferredLanguages: ["en"]).uppercased()
        )

        controller.didReceive(status: nil)
        XCTAssertTrue(controller.rootView.statusView.isHidden)
    }

    func testLoadableContentUsesScrollableContent() throws {
        let output = CovCPMPoolInfoViewOutputSpy()
        let controller = try makeController(output: output)

        XCTAssertTrue(controller.loadableContentView === controller.rootView.contentView)
        XCTAssertFalse(controller.shouldDisableInteractionWhenLoading)

        controller.didStartLoading()

        XCTAssertNotNil(
            CovCPMPoolInfoViewFixtures.findSubview(
                withIdentifier: LoadableViewProtocolConstants.activityIndicatorIdentifier,
                in: controller.view
            )
        )
        XCTAssertTrue(controller.rootView.contentView.isUserInteractionEnabled)
    }
}
