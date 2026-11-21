import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPMMainViewOutputSpy: StakingPoolMainViewOutput {
    private(set) var didLoadCount = 0
    private(set) var selectAssetCount = 0
    private(set) var startStakingCount = 0
    private(set) var accountSelectionCount = 0
    private(set) var rewardInfoCount = 0
    private(set) var amounts: [Decimal] = []
    private(set) var percentages: [Float] = []
    private(set) var expansions: [Bool] = []
    private(set) var stakeInfoCount = 0
    private(set) var statusCount = 0

    func didLoad(view _: StakingPoolMainViewInput) { didLoadCount += 1 }
    func didTapSelectAsset() { selectAssetCount += 1 }
    func didTapStartStaking() { startStakingCount += 1 }
    func didTapAccountSelection() { accountSelectionCount += 1 }
    func performRewardInfoAction() { rewardInfoCount += 1 }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func networkInfoViewDidChangeExpansion(isExpanded: Bool) { expansions.append(isExpanded) }
    func didTapStakeInfoView() { stakeInfoCount += 1 }
    func didTapStatusView() { statusCount += 1 }
}

enum CovCPMMainViewFixtures {
    static func chainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        return ChainAsset(chain: chain, asset: asset)
    }

    static func nominationResource(status: NominationViewStatus) -> LocalizableResource<NominationViewModelProtocol> {
        LocalizableResource { _ in
            NominationViewModel(
                totalStakedAmount: "12 DOT",
                totalStakedPrice: "$60",
                totalRewardAmount: "1 DOT",
                totalRewardPrice: "$5",
                status: status,
                hasPrice: true,
                redeemableViewModel: StakingUnitInfoViewModel(value: "2 DOT", subtitle: "$10"),
                unstakingViewModel: StakingUnitInfoViewModel(value: "3 DOT", subtitle: "$15"),
                rewardViewTitle: "Claimable"
            )
        }
    }

    static func networkInfo() -> [LocalizableResource<NetworkInfoContentViewModel>] {
        [
            LocalizableResource { _ in NetworkInfoContentViewModel(title: "Min join", value: "1 DOT", details: nil) },
            LocalizableResource { _ in NetworkInfoContentViewModel(title: "Pools", value: "12", details: "details") }
        ]
    }

    static func estimation(chainAsset: ChainAsset) -> StakingEstimationViewModel {
        let wallet = AccountGenerator.generateMetaAccount()
        let factory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet)
        return StakingEstimationViewModel(
            assetBalance: factory.createAssetBalanceViewModel(5, balance: 10, priceData: nil),
            rewardViewModel: nil,
            assetInfo: chainAsset.assetDisplayInfo,
            inputLimit: StakingConstants.maxAmount,
            amount: 5
        )
    }

    static func allLabelTexts(in view: UIView) -> [String] {
        var texts: [String] = []
        if let label = view as? UILabel, let text = label.text {
            texts.append(text)
        }
        for subview in view.subviews {
            texts.append(contentsOf: allLabelTexts(in: subview))
        }
        return texts
    }
}

final class CovCPMPoolMainViewLayoutTests: XCTestCase {
    private let languages = ["en"]

    private func makeLayout() -> StakingPoolMainViewLayout {
        let view = StakingPoolMainViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = Locale(identifier: "en")
        view.layoutIfNeeded()
        return view
    }

    func testLocalizationSetsTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.titleLabel.text, R.string.localizable.commonStaking(preferredLanguages: languages))
        XCTAssertEqual(
            view.networkInfoView.titleControl.titleLabel.text,
            R.string.localizable.poolStakingTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.networkInfoView.descriptionLabel.text,
            R.string.localizable.poolStakingMainDescriptionTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.startStakingButton.imageWithTitleView?.title,
            R.string.localizable.stakingStartTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.assetSelectionView.additionalInfoView?.title(for: .normal),
            R.string.localizable.poolCommon(preferredLanguages: languages).uppercased()
        )
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
        XCTAssertEqual(view.rewardCalculatorView.locale.identifier, "en")
    }

    func testBindChainAssetAndBalance() {
        let view = makeLayout()
        let chainAsset = CovCPMMainViewFixtures.chainAsset()

        view.bind(chainAsset: chainAsset)
        view.bind(balanceViewModel: BalanceViewModel(amount: "99 DOT", price: nil))

        XCTAssertEqual(view.assetSelectionView.title, "DOT")
        XCTAssertEqual(view.assetSelectionView.subtitle, "99 DOT")
    }

    func testBindEstimationConfiguresCalculator() {
        let view = makeLayout()
        XCTAssertNil(view.rewardCalculatorView.amountFormatterFactory)

        view.bind(estimationViewModel: CovCPMMainViewFixtures.estimation(chainAsset: CovCPMMainViewFixtures.chainAsset()))

        XCTAssertNotNil(view.rewardCalculatorView.amountFormatterFactory)
    }

    func testBindNetworkInfoAddsRows() {
        let view = makeLayout()

        view.bind(viewModels: CovCPMMainViewFixtures.networkInfo())

        let texts = CovCPMMainViewFixtures.allLabelTexts(in: view.networkInfoView)
        XCTAssertTrue(texts.contains("Min join"))
        XCTAssertTrue(texts.contains("12"))
    }

    func testBindNominatorStateTogglesSections() {
        let view = makeLayout()

        view.bind(nominatorStateViewModel: nil)
        XCTAssertTrue(view.nominatorStateView.isHidden)
        XCTAssertFalse(view.rewardCalculatorView.isHidden)
        XCTAssertFalse(view.startStakingButton.isHidden)

        view.bind(nominatorStateViewModel: CovCPMMainViewFixtures.nominationResource(status: .validatorsNotSelected))
        XCTAssertFalse(view.nominatorStateView.isHidden)
        XCTAssertTrue(view.rewardCalculatorView.isHidden)
        XCTAssertTrue(view.startStakingButton.isHidden)
        XCTAssertEqual(view.nominatorStateView.stakeAmountView.valueLabel.text, "12 DOT")
        XCTAssertEqual(view.nominatorStateView.rewardAmountView.valueLabel.text, "1 DOT")
    }
}

final class CovCPMPoolMainViewControllerTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController(output: CovCPMMainViewOutputSpy) throws -> StakingPoolMainViewController {
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingPoolMainViewController(output: output, localizationManager: manager)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        controller.loadViewIfNeeded()
        return controller
    }

    func testLoadConfiguresViewAndNotifiesOutput() throws {
        let output = CovCPMMainViewOutputSpy()
        let controller = try makeController(output: output)

        XCTAssertEqual(output.didLoadCount, 1)
        XCTAssertTrue(controller.rootView.networkInfoView.collectionView.isHidden)
        XCTAssertTrue(controller.rootView.rewardCalculatorView.delegate === controller)
        XCTAssertTrue(controller.rootView.networkInfoView.delegate === controller)
        XCTAssertTrue(controller.rootView.nominatorStateView.delegate === controller)
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
    }

    func testControlsForwardActions() throws {
        let output = CovCPMMainViewOutputSpy()
        let controller = try makeController(output: output)

        controller.rootView.assetSelectionView.sendActions(for: .touchUpInside)
        controller.rootView.startStakingButton.sendActions(for: .touchUpInside)
        controller.rootView.walletSelectionButton.sendActions(for: .touchUpInside)
        controller.rootView.nominatorStateView.moreButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.selectAssetCount, 1)
        XCTAssertEqual(output.startStakingCount, 1)
        XCTAssertEqual(output.accountSelectionCount, 1)
        XCTAssertEqual(output.stakeInfoCount, 1)
    }

    func testDelegateCallbacksForwardToOutput() throws {
        let output = CovCPMMainViewOutputSpy()
        let controller = try makeController(output: output)
        let calculator = controller.rootView.rewardCalculatorView

        controller.rewardCalculatorView(calculator, didChange: 7)
        controller.rewardCalculatorView(calculator, didChange: nil)
        controller.rewardCalculatorView(calculator, didSelect: 0.5)
        controller.rewardCalculatorDidRequestInfo(calculator)
        controller.didChangeExpansion(isExpanded: true, view: controller.rootView.networkInfoView)
        controller.animateAlongsideWithInfo(view: controller.rootView.networkInfoView)
        controller.stakingStateViewDidReceiveStatusAction(controller.rootView.nominatorStateView)
        controller.stakingStateViewDidReceiveMoreAction(controller.rootView.nominatorStateView)

        XCTAssertEqual(output.amounts, [7, 0])
        XCTAssertEqual(output.percentages, [0.5])
        XCTAssertEqual(output.rewardInfoCount, 1)
        XCTAssertEqual(output.expansions, [true])
        XCTAssertEqual(output.statusCount, 1)
        XCTAssertEqual(output.stakeInfoCount, 0)
    }

    func testViewInputBindsRootView() throws {
        let output = CovCPMMainViewOutputSpy()
        let controller = try makeController(output: output)
        let chainAsset = CovCPMMainViewFixtures.chainAsset()

        controller.didReceiveChainAsset(chainAsset)
        controller.didReceiveBalanceViewModel(BalanceViewModel(amount: "5 DOT", price: "$1"))
        controller.didReceiveEstimationViewModel(CovCPMMainViewFixtures.estimation(chainAsset: chainAsset))
        controller.didReceiveNetworkInfoViewModels(CovCPMMainViewFixtures.networkInfo())
        controller.didReceiveNominatorStateViewModel(CovCPMMainViewFixtures.nominationResource(status: .inactive(era: 3)))

        XCTAssertEqual(controller.rootView.assetSelectionView.title, "DOT")
        XCTAssertEqual(controller.rootView.assetSelectionView.subtitle, "5 DOT")
        XCTAssertNotNil(controller.rootView.rewardCalculatorView.amountFormatterFactory)
        XCTAssertTrue(CovCPMMainViewFixtures.allLabelTexts(in: controller.rootView.networkInfoView).contains("Pools"))
        XCTAssertFalse(controller.rootView.nominatorStateView.isHidden)

        controller.didReceiveNominatorStateViewModel(nil)
        XCTAssertTrue(controller.rootView.nominatorStateView.isHidden)
    }

    func testKeyboardHandlingLifecycle() throws {
        let output = CovCPMMainViewOutputSpy()
        let controller = try makeController(output: output)

        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertTrue(controller.target === controller.rootView.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(120), 0)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), 0)
        controller.updateWhileKeyboardFrameChanging(.zero)

        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testOffsetFromKeyboardUsesTabBarHeight() throws {
        let output = CovCPMMainViewOutputSpy()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = StakingPoolMainViewController(output: output, localizationManager: manager)
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [controller]
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        self.window = window
        window.layoutIfNeeded()

        let tabBarHeight = tabBarController.tabBar.frame.height
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(100), -tabBarHeight)
    }
}
