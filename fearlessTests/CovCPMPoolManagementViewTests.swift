import XCTest
import SoraFoundation
@testable import fearless

final class CovCPMManagementViewOutputSpy: StakingPoolManagementViewOutput {
    private(set) var didLoadCount = 0
    private(set) var closeCount = 0
    private(set) var stakeMoreCount = 0
    private(set) var unstakeCount = 0
    private(set) var optionsCount = 0
    private(set) var claimCount = 0
    private(set) var redeemCount = 0
    private(set) var selectValidatorsCount = 0
    private(set) var poolInfoCount = 0

    func didLoad(view _: StakingPoolManagementViewInput) { didLoadCount += 1 }
    func didTapCloseButton() { closeCount += 1 }
    func didTapStakeMoreButton() { stakeMoreCount += 1 }
    func didTapUnstakeButton() { unstakeCount += 1 }
    func didTapOptionsButton() { optionsCount += 1 }
    func didTapClaimButton() { claimCount += 1 }
    func didTapRedeemButton() { redeemCount += 1 }
    func didTapSelectValidators() { selectValidatorsCount += 1 }
    func didTapPoolInfoName() { poolInfoCount += 1 }
}

final class CovCPMPoolManagementViewLayoutTests: XCTestCase {
    private let languages = ["en"]

    private func makeLayout() -> StakingPoolManagementViewLayout {
        let view = StakingPoolManagementViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = Locale(identifier: "en")
        view.layoutIfNeeded()
        return view
    }

    func testLocalizationSetsTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.stakingPoolInfoTitle(preferredLanguages: languages))
        XCTAssertEqual(view.stakeMoreButton.imageWithTitleView?.title, R.string.localizable.stakingBondMore_v190(preferredLanguages: languages))
        XCTAssertEqual(view.unstakeButton.imageWithTitleView?.title, R.string.localizable.stakingUnbond_v190(preferredLanguages: languages))
        XCTAssertEqual(view.balanceView.titleLabel.text, R.string.localizable.walletBalanceAvailable(preferredLanguages: languages))
        XCTAssertEqual(
            view.unstakingView.titleLabel.text,
            R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: languages)
        )
        XCTAssertEqual(view.poolInfoView.titleLabel.text, R.string.localizable.stakingPoolInfoTitle(preferredLanguages: languages))
        XCTAssertEqual(
            view.reedeemDelayView.titleLabel.text,
            R.string.localizable.poolStakingRedeemDelayTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.selectValidatorsView.title,
            R.string.localizable.stakingPoolManagementSelectValidatorsTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.selectValidatorsView.subtitle,
            R.string.localizable.stakingPoolManagementSelectValidatorsSubtitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.selectValidatorsView.actionButton?.imageWithTitleView?.title,
            R.string.localizable.commonSelect(preferredLanguages: languages)
        )
        XCTAssertEqual(view.claimView.title, R.string.localizable.poolStakingManagementClaimTitle(preferredLanguages: languages))
        XCTAssertEqual(view.redeemView.title, R.string.localizable.poolStakingManagementRedeemTitle(preferredLanguages: languages))
        XCTAssertEqual(
            view.claimView.actionButton?.imageWithTitleView?.title,
            R.string.localizable.poolStakingManagementClaimButtonTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(view.redeemView.actionButton?.imageWithTitleView?.title, R.string.localizable.stakingRedeem(preferredLanguages: languages))
    }

    func testInitialStateHidesOptionalSections() {
        let view = makeLayout()

        XCTAssertTrue(view.stakeMoreButton.isHidden)
        XCTAssertTrue(view.unstakeButton.isHidden)
        XCTAssertTrue(view.selectValidatorsView.isHidden)
        XCTAssertTrue(view.claimView.isHidden)
        XCTAssertTrue(view.redeemView.isHidden)
        XCTAssertEqual(view.optionsButton.layer.cornerRadius, view.optionsButton.frame.size.height / 2)
    }

    func testBindPoolName() {
        let view = makeLayout()

        view.bind(poolName: "My pool")
        XCTAssertEqual(view.poolInfoView.valueLabel.text, "My pool")
        XCTAssertNotNil(view.poolInfoView.valueImageView.image)
        XCTAssertFalse(view.poolInfoView.activityIndicator.isAnimating)

        view.bind(poolName: nil)
        XCTAssertNil(view.poolInfoView.valueLabel.text)
        XCTAssertTrue(view.poolInfoView.activityIndicator.isAnimating)
    }

    func testBindBalancesAndStakedAmount() {
        let view = makeLayout()

        view.bind(balanceViewModel: BalanceViewModel(amount: "4 DOT", price: "$20"))
        view.bind(unstakeBalanceViewModel: BalanceViewModel(amount: "1 DOT", price: nil))
        view.bind(stakedAmountString: NSAttributedString(string: "Total 9 DOT"))

        XCTAssertEqual(view.balanceView.valueTop.text, "4 DOT")
        XCTAssertEqual(view.balanceView.valueBottom.text, "$20")
        XCTAssertEqual(view.unstakingView.valueTop.text, "1 DOT")
        XCTAssertTrue(view.unstakingView.valueBottom.isHidden)
        XCTAssertEqual(view.totalStakeLabel.attributedText?.string, "Total 9 DOT")
    }

    func testBindRedeemDelay() {
        let view = makeLayout()

        view.bind(redeemDelayViewModel: LocalizableResource { _ in "3 days" })
        XCTAssertFalse(view.reedeemDelayView.isHidden)
        XCTAssertEqual(view.reedeemDelayView.valueLabel.text, "3 days")

        view.bind(redeemDelayViewModel: nil)
        XCTAssertTrue(view.reedeemDelayView.isHidden)
    }

    func testBindClaimableAndRedeemable() {
        let view = makeLayout()

        view.bind(claimableViewModel: BalanceViewModel(amount: "0.5 DOT", price: nil))
        view.bind(redeemableViewModel: BalanceViewModel(amount: "2 DOT", price: nil))
        XCTAssertFalse(view.claimView.isHidden)
        XCTAssertEqual(view.claimView.subtitle, "0.5 DOT")
        XCTAssertFalse(view.redeemView.isHidden)
        XCTAssertEqual(view.redeemView.subtitle, "2 DOT")

        view.bind(claimableViewModel: nil)
        view.bind(redeemableViewModel: nil)
        XCTAssertTrue(view.claimView.isHidden)
        XCTAssertTrue(view.redeemView.isHidden)
    }

    func testBindViewModelAndValidatorsAlert() {
        let view = makeLayout()

        view.bind(viewModel: StakingPoolManagementViewModel(stakeMoreButtonVisible: true, unstakeButtonVisible: false))
        XCTAssertFalse(view.stakeMoreButton.isHidden)
        XCTAssertTrue(view.unstakeButton.isHidden)

        view.bind(viewModel: nil)
        XCTAssertFalse(view.stakeMoreButton.isHidden)
        XCTAssertFalse(view.unstakeButton.isHidden)

        view.setSelectValidatorsAlert(visible: true)
        XCTAssertFalse(view.selectValidatorsView.isHidden)
        view.setSelectValidatorsAlert(visible: false)
        XCTAssertTrue(view.selectValidatorsView.isHidden)
    }
}

final class CovCPMPoolManagementViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController(output: CovCPMManagementViewOutputSpy) throws -> StakingPoolManagementViewController {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingPoolManagementViewController(output: output, localizationManager: manager)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        controller.loadViewIfNeeded()
        return controller
    }

    func testLoadNotifiesOutputAndLocalizes() throws {
        let output = CovCPMManagementViewOutputSpy()
        let controller = try makeController(output: output)

        XCTAssertEqual(output.didLoadCount, 1)
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
        XCTAssertEqual(controller.rootView.poolInfoView.gestureRecognizers?.count, 1)
    }

    func testButtonsForwardActions() throws {
        let output = CovCPMManagementViewOutputSpy()
        let controller = try makeController(output: output)
        let root = controller.rootView

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.stakeMoreButton.sendActions(for: .touchUpInside)
        root.unstakeButton.sendActions(for: .touchUpInside)
        root.optionsButton.sendActions(for: .touchUpInside)
        root.redeemView.actionButton?.sendActions(for: .touchUpInside)
        root.claimView.actionButton?.sendActions(for: .touchUpInside)
        root.selectValidatorsView.actionButton?.sendActions(for: .touchUpInside)
        controller.perform(NSSelectorFromString("poolInfoNameTapped"))

        XCTAssertEqual(output.closeCount, 1)
        XCTAssertEqual(output.stakeMoreCount, 1)
        XCTAssertEqual(output.unstakeCount, 1)
        XCTAssertEqual(output.optionsCount, 1)
        XCTAssertEqual(output.redeemCount, 1)
        XCTAssertEqual(output.claimCount, 1)
        XCTAssertEqual(output.selectValidatorsCount, 1)
        XCTAssertEqual(output.poolInfoCount, 1)
    }

    func testViewInputBindsRootView() throws {
        let output = CovCPMManagementViewOutputSpy()
        let controller = try makeController(output: output)
        let root = controller.rootView

        controller.didReceive(poolName: "Pool 5")
        controller.didReceive(balanceViewModel: BalanceViewModel(amount: "8 DOT", price: nil))
        controller.didReceive(unstakingViewModel: BalanceViewModel(amount: "2 DOT", price: nil))
        controller.didReceive(stakedAmountString: NSAttributedString(string: "staked"))
        controller.didReceive(redeemDelayViewModel: LocalizableResource { _ in "1 day" })
        controller.didReceive(claimableViewModel: BalanceViewModel(amount: "0.1 DOT", price: nil))
        controller.didReceive(redeemableViewModel: BalanceViewModel(amount: "0.2 DOT", price: nil))
        controller.didReceive(viewModel: StakingPoolManagementViewModel(stakeMoreButtonVisible: true, unstakeButtonVisible: true))
        controller.didReceiveSelectValidator(visible: true)

        XCTAssertEqual(root.poolInfoView.valueLabel.text, "Pool 5")
        XCTAssertEqual(root.balanceView.valueTop.text, "8 DOT")
        XCTAssertEqual(root.unstakingView.valueTop.text, "2 DOT")
        XCTAssertEqual(root.totalStakeLabel.attributedText?.string, "staked")
        XCTAssertEqual(root.reedeemDelayView.valueLabel.text, "1 day")
        XCTAssertEqual(root.claimView.subtitle, "0.1 DOT")
        XCTAssertEqual(root.redeemView.subtitle, "0.2 DOT")
        XCTAssertFalse(root.stakeMoreButton.isHidden)
        XCTAssertFalse(root.unstakeButton.isHidden)
        XCTAssertFalse(root.selectValidatorsView.isHidden)

        controller.applyLocalization()
        XCTAssertEqual(root.claimView.title, R.string.localizable.poolStakingManagementClaimTitle(preferredLanguages: ["en"]))
    }
}
