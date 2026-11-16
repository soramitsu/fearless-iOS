import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCABSAVPresenter: StakingAmountPresenterProtocol {
    private(set) var setupCalls = 0
    private(set) var restakeCalls = 0
    private(set) var payoutCalls = 0
    private(set) var percentages: [Float] = []
    private(set) var payoutAccountCalls = 0
    private(set) var updatedAmounts: [Decimal] = []
    private(set) var learnMoreCalls = 0
    private(set) var proceedCalls = 0
    private(set) var closeCalls = 0

    func setup() { setupCalls += 1 }
    func selectRestakeDestination() { restakeCalls += 1 }
    func selectPayoutDestination() { payoutCalls += 1 }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func selectPayoutAccount() { payoutAccountCalls += 1 }
    func updateAmount(_ newValue: Decimal) { updatedAmounts.append(newValue) }
    func selectLearnMore() { learnMoreCalls += 1 }
    func proceed() { proceedCalls += 1 }
    func close() { closeCalls += 1 }
}

final class CovCABStakingAmountViewControllerTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]
    private var presenter: CovCABSAVPresenter!
    private var controller: StakingAmountViewController!
    private var window: UIWindow!
    private var balanceFactory: BalanceViewModelFactory!

    override func setUp() {
        super.setUp()
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        balanceFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: AccountGenerator.generateMetaAccount()
        )
        presenter = CovCABSAVPresenter()
        controller = StakingAmountViewController(
            nibName: "StakingAmountViewController",
            bundle: Bundle(for: StakingAmountViewController.self)
        )
        controller.uiFactory = UIFactory.default
        controller.localizationManager = LocalizationManager(localization: "en")
        controller.presenter = presenter

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        controller = nil
        presenter = nil
        balanceFactory = nil
        super.tearDown()
    }

    private func outlet<T>(_ name: String, as _: T.Type) throws -> T {
        try XCTUnwrap(controller.value(forKey: name) as? T)
    }

    private func payoutViewModel(restakeAvailable: Bool) -> RewardDestinationViewModel {
        RewardDestinationViewModel(
            rewardViewModel: DestinationReturnViewModel(
                restakeAmount: "2 DOT",
                restakePercentage: "20%",
                restakePrice: "$4",
                payoutAmount: "1 DOT",
                payoutPercentage: "10%",
                payoutPrice: "$2",
                restakeAvailable: restakeAvailable
            ),
            type: .payout(icon: nil, title: "Payout account", address: "address")
        )
    }

    func testViewDidLoadAppliesLocalizationAndCallsSetup() throws {
        XCTAssertEqual(presenter.setupCalls, 1)
        XCTAssertEqual(controller.title, R.string.localizable.stakingStake(preferredLanguages: languages))

        let titleLabel = try outlet("rewardDestinationTitleLabel", as: UILabel.self)
        XCTAssertEqual(
            titleLabel.text,
            R.string.localizable.stakingSetupRewardDestinationSectionTitle(preferredLanguages: languages)
        )
        let restakeView = try outlet("restakeView", as: RewardSelectionView.self)
        XCTAssertEqual(restakeView.title, R.string.localizable.stakingSetupRestakeTitle(preferredLanguages: languages))
        let payoutView = try outlet("payoutView", as: RewardSelectionView.self)
        XCTAssertEqual(payoutView.title, R.string.localizable.commonPayout(preferredLanguages: languages))
        let actionButton = try outlet("actionButton", as: TriangularedButton.self)
        XCTAssertFalse(actionButton.isEnabled)
        let chooseRewardView = try outlet("chooseRewardView", as: UIView.self)
        XCTAssertTrue(chooseRewardView.isHidden)
        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        XCTAssertTrue(amountInput.textField.inputAccessoryView is AmountInputAccessoryView)
        XCTAssertTrue(amountInput.textField.delegate === controller)
    }

    func testAssetViewModelFillsAmountInput() throws {
        let asset = balanceFactory.createAssetBalanceViewModel(2, balance: 10, priceData: nil)
        controller.didReceiveAsset(viewModel: asset)

        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        let expected = asset.value(for: locale)
        XCTAssertEqual(
            amountInput.balanceText,
            R.string.localizable.commonAvailableFormat(expected.balance ?? "", preferredLanguages: languages)
        )
        XCTAssertEqual(amountInput.symbol, expected.symbol)
    }

    func testRestakeDestinationSelectsRestake() throws {
        let viewModel = RewardDestinationViewModel(
            rewardViewModel: DestinationReturnViewModel(
                restakeAmount: "2 DOT",
                restakePercentage: "20%",
                restakePrice: "$4",
                payoutAmount: "1 DOT",
                payoutPercentage: "10%",
                payoutPrice: "$2",
                restakeAvailable: true
            ),
            type: .restake
        )
        controller.didReceiveRewardDestination(viewModel: LocalizableResource { _ in viewModel })

        let restakeView = try outlet("restakeView", as: RewardSelectionView.self)
        let payoutView = try outlet("payoutView", as: RewardSelectionView.self)
        let chooseRewardView = try outlet("chooseRewardView", as: UIView.self)
        XCTAssertFalse(chooseRewardView.isHidden)
        XCTAssertTrue(restakeView.isSelected)
        XCTAssertFalse(payoutView.isSelected)
        XCTAssertFalse(restakeView.isHidden)
        XCTAssertEqual(restakeView.amountTitle, "2 DOT")
        XCTAssertEqual(restakeView.incomeTitle, "20%")
        XCTAssertEqual(restakeView.priceTitle, "$4")
        XCTAssertEqual(payoutView.amountTitle, "1 DOT")
        XCTAssertEqual(payoutView.incomeTitle, "10%")
        XCTAssertEqual(payoutView.priceTitle, "$2")

        restakeView.sendActions(for: .touchDown)
        payoutView.sendActions(for: .touchDown)
        XCTAssertEqual(presenter.restakeCalls, 0)
        XCTAssertEqual(presenter.payoutCalls, 1)
    }

    func testPayoutDestinationAddsAndRemovesAccountRow() throws {
        let stackView = try outlet("stackView", as: UIStackView.self)
        let initialCount = stackView.arrangedSubviews.count

        controller.didReceiveRewardDestination(viewModel: LocalizableResource { _ in self.payoutViewModel(restakeAvailable: false) })

        let restakeView = try outlet("restakeView", as: RewardSelectionView.self)
        let payoutView = try outlet("payoutView", as: RewardSelectionView.self)
        XCTAssertTrue(payoutView.isSelected)
        XCTAssertFalse(restakeView.isSelected)
        XCTAssertTrue(restakeView.isHidden)
        XCTAssertEqual(stackView.arrangedSubviews.count, initialCount + 1)

        controller.applyLocalization()
        XCTAssertEqual(stackView.arrangedSubviews.count, initialCount + 1)

        restakeView.sendActions(for: .touchDown)
        XCTAssertEqual(presenter.restakeCalls, 1)

        let restake = RewardDestinationViewModel(rewardViewModel: nil, type: .restake)
        controller.didReceiveRewardDestination(viewModel: LocalizableResource { _ in restake })
        XCTAssertEqual(stackView.arrangedSubviews.count, initialCount)
        XCTAssertTrue(restakeView.isSelected)
    }

    func testMainViewModelEnablesActionButton() throws {
        let input = balanceFactory.createBalanceInputViewModel(5)
        let fee = balanceFactory.balanceFromPrice(1, priceData: nil, usageCase: .detailsCrypto)
        let asset = balanceFactory.createAssetBalanceViewModel(5, balance: 10, priceData: nil)
        let destination = RewardDestinationViewModel(rewardViewModel: nil, type: .restake)

        controller.didReceive(viewModel: StakingAmountMainViewModel(
            assetViewModel: asset,
            rewardDestinationViewModel: LocalizableResource { _ in destination },
            feeViewModel: fee,
            inputViewModel: input,
            continueAvailable: true
        ))

        let actionButton = try outlet("actionButton", as: TriangularedButton.self)
        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        XCTAssertTrue(actionButton.isEnabled)
        XCTAssertEqual(amountInput.fieldText, input.value(for: locale).displayAmount)

        controller.didReceive(viewModel: StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: nil,
            feeViewModel: nil,
            inputViewModel: nil,
            continueAvailable: false
        ))
        XCTAssertFalse(actionButton.isEnabled)
        let chooseRewardView = try outlet("chooseRewardView", as: UIView.self)
        XCTAssertTrue(chooseRewardView.isHidden)

        controller.didReceiveFee(viewModel: nil)
        XCTAssertFalse(actionButton.isEnabled)
    }

    func testLoadingTogglesButtonInteraction() throws {
        let actionButton = try outlet("actionButton", as: TriangularedButton.self)

        controller.didStartLoading()
        XCTAssertFalse(actionButton.isUserInteractionEnabled)

        controller.didStopLoading()
        XCTAssertTrue(actionButton.isUserInteractionEnabled)
    }

    func testInputChangesForwardAmountToPresenter() throws {
        let input = balanceFactory.createBalanceInputViewModel(nil).value(for: locale)
        controller.didReceiveInput(viewModel: LocalizableResource { _ in input })

        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        let textField = try XCTUnwrap(amountInput.textField)
        _ = controller.textField(
            textField,
            shouldChangeCharactersIn: NSRange(location: input.displayAmount.count, length: 0),
            replacementString: "7"
        )

        XCTAssertFalse(presenter.updatedAmounts.isEmpty)
        XCTAssertEqual(presenter.updatedAmounts.last, input.decimalAmount ?? 0)

        controller.amountInputDidChange()
        XCTAssertEqual(amountInput.fieldText, input.displayAmount)
        XCTAssertEqual(presenter.updatedAmounts.last, input.decimalAmount ?? 0)
    }

    func testTextFieldWithoutInputViewModelRejectsChanges() throws {
        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        let allowed = controller.textField(
            amountInput.textField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "1"
        )

        XCTAssertFalse(allowed)
        controller.amountInputDidChange()
        XCTAssertEqual(presenter.updatedAmounts, [0])
    }

    func testAccessoryPercentageAndDone() throws {
        let amountInput = try outlet("amountInputView", as: AmountInputView.self)
        let accessory = try XCTUnwrap(amountInput.textField.inputAccessoryView as? AmountInputAccessoryView)

        accessory.actionSelect50()
        accessory.actionSelect100()
        accessory.actionSelectDone()

        XCTAssertEqual(presenter.percentages, [0.5, 1.0])
    }

    func testButtonsAndSelectorsReachPresenter() throws {
        let actionButton = try outlet("actionButton", as: TriangularedButton.self)
        actionButton.set(enabled: true)
        actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.proceedCalls, 1)

        let learnMore = try outlet("learnMoreView", as: UIControl.self)
        learnMore.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.learnMoreCalls, 1)

        controller.perform(NSSelectorFromString("actionClose"))
        XCTAssertEqual(presenter.closeCalls, 1)

        controller.perform(NSSelectorFromString("actionSelectPayoutAccount"))
        XCTAssertEqual(presenter.payoutAccountCalls, 1)
    }

    func testApplyLocalizationResetsTitle() {
        controller.title = "temp"
        controller.applyLocalization()

        XCTAssertEqual(controller.title, R.string.localizable.stakingStake(preferredLanguages: languages))
    }
}
