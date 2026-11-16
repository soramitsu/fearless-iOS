import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJPoolCreateOutputDouble: StakingPoolCreateViewOutput {
    private(set) var loadedView: StakingPoolCreateViewInput?
    private(set) var percentages: [Float] = []
    private(set) var amounts: [Decimal] = []
    private(set) var nominatorTaps = 0
    private(set) var bouncerTaps = 0
    private(set) var createTaps = 0
    private(set) var backTaps = 0
    private(set) var nameChanges = 0
    private(set) var rootTaps = 0

    func didLoad(view: StakingPoolCreateViewInput) { loadedView = view }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func nominatorDidTapped() { nominatorTaps += 1 }
    func bouncerDidTapped() { bouncerTaps += 1 }
    func createDidTapped() { createTaps += 1 }
    func backDidTapped() { backTaps += 1 }
    func nameTextFieldInputValueChanged() { nameChanges += 1 }
    func rootDidTapped() { rootTaps += 1 }
}

final class CovCPJPoolCreateViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func makeLayout() -> StakingPoolCreateViewLayout {
        let view = StakingPoolCreateViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func makeController() throws -> (StakingPoolCreateViewController, CovCPJPoolCreateOutputDouble) {
        let output = CovCPJPoolCreateOutputDouble()
        let controller = StakingPoolCreateViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()
        return (controller, output)
    }

    private func viewModel(poolId: Int?) -> StakingPoolCreateViewModel {
        StakingPoolCreateViewModel(
            poolId: poolId,
            depositor: "Depositor",
            root: "Root wallet",
            naminator: "Nominator wallet",
            bouncer: "Bouncer wallet"
        )
    }

    // MARK: - Layout

    func testLayoutAppliesLocalizedTitles() {
        let view = makeLayout()

        XCTAssertEqual(
            view.navigationBar.titleLabel.text,
            R.string.localizable.stakingPoolCreateTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(view.poolNameInputView.title, R.string.localizable.poolStakingPoolName(preferredLanguages: languages))
        XCTAssertEqual(view.advancedTitleLabel.text, R.string.localizable.commonAdvanced(preferredLanguages: languages))
        XCTAssertEqual(
            view.feeView.actionButton.imageWithTitleView?.title,
            R.string.localizable.commonCreate(preferredLanguages: languages)
        )
        XCTAssertEqual(view.poolIdView.title, R.string.localizable.stakingPoolCreatePoolId(preferredLanguages: languages))
        XCTAssertEqual(
            view.depositorView.title,
            R.string.localizable.stakingPoolCreateDepositor(preferredLanguages: languages)
        )
        XCTAssertEqual(view.rootAccountView.title, R.string.localizable.stakingPoolCreateRoot(preferredLanguages: languages))
        XCTAssertEqual(
            view.nominatorView.title,
            R.string.localizable.stakingPoolCreateNominator(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.bouncerView.title,
            R.string.localizable.stakingPoolCreateStateToggler(preferredLanguages: languages)
        )
        XCTAssertNotNil(view.keyboardAdoptableConstraint)
    }

    func testBindViewModelWithPoolIdFillsAllRoleFields() {
        let view = makeLayout()

        view.bind(viewModel: viewModel(poolId: 42))

        XCTAssertEqual(view.poolIdView.text, "42")
        XCTAssertEqual(view.depositorView.text, "Depositor")
        XCTAssertEqual(view.rootAccountView.subtitle, "Root wallet")
        XCTAssertEqual(view.nominatorView.subtitle, "Nominator wallet")
        XCTAssertEqual(view.bouncerView.subtitle, "Bouncer wallet")
    }

    func testBindViewModelWithoutPoolIdKeepsPoolIdEmpty() {
        let view = makeLayout()

        view.bind(viewModel: viewModel(poolId: nil))

        XCTAssertTrue(view.poolIdView.text?.isEmpty ?? true)
        XCTAssertEqual(view.depositorView.text, "Depositor")
    }

    func testBindAssetViewModelShowsSymbolAndBalance() {
        let view = makeLayout()
        let viewModel = AssetBalanceViewModel(
            symbol: "dot",
            balance: "12.5",
            fiatBalance: nil,
            price: "$3",
            iconViewModel: nil,
            selectable: true
        )

        view.bind(assetViewModel: viewModel)

        let texts = CovCPJFixtures.labelTexts(in: view.amountView)
        XCTAssertTrue(texts.contains("DOT"))
        XCTAssertTrue(texts.contains("$3"))
        XCTAssertTrue(texts.contains { $0.contains("12.5") })
    }

    func testAdvancedSectionExpandsAndCollapses() {
        let view = makeLayout()
        XCTAssertNil(view.expandView.superview)

        view.perform(NSSelectorFromString("handleIndicatorTapped"))
        view.layoutIfNeeded()

        XCTAssertTrue(view.expandView.superview === view.contentView.stackView)
        XCTAssertTrue(view.indicator.isActivated)
        XCTAssertTrue(view.poolIdView.superview === view.expandView)
        XCTAssertTrue(view.bouncerView.superview === view.expandView)

        view.perform(NSSelectorFromString("handleIndicatorTapped"))

        XCTAssertNil(view.expandView.superview)
        XCTAssertFalse(view.indicator.isActivated)
    }

    // MARK: - View model factory

    func testViewModelFactoryIncrementsLastPoolIdAndUsesWalletNames() {
        let factory = StakingPoolCreateViewModelFactory()
        let depositor = CovCPJFixtures.wallet()
        let nominator = CovCPJFixtures.wallet()
        let bouncer = CovCPJFixtures.wallet()
        let root = CovCPJFixtures.wallet()

        let viewModel = factory.buildViewModel(
            wallet: depositor,
            nominatorWallet: nominator,
            bouncer: bouncer,
            rootWallet: root,
            lastPoolId: 9
        )

        XCTAssertEqual(viewModel.poolId, 10)
        XCTAssertEqual(viewModel.depositor, depositor.name)
        XCTAssertEqual(viewModel.naminator, nominator.name)
        XCTAssertEqual(viewModel.bouncer, bouncer.name)
        XCTAssertEqual(viewModel.root, root.name)

        let withoutId = factory.buildViewModel(
            wallet: depositor,
            nominatorWallet: depositor,
            bouncer: depositor,
            rootWallet: depositor,
            lastPoolId: nil
        )
        XCTAssertNil(withoutId.poolId)
    }

    // MARK: - View controller

    func testControllerLoadNotifiesOutputAndDisablesAction() throws {
        let (controller, output) = try makeController()

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertFalse(controller.rootView.feeView.actionButton.isEnabled)
        XCTAssertTrue(controller.rootView.amountView.textField.inputAccessoryView is AmountInputAccessoryView)
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.stakingPoolCreateTitle(preferredLanguages: languages)
        )
    }

    func testControllerKeyboardHandlerLifecycle() throws {
        let (controller, _) = try makeController()
        let window = CovCPJFixtures.host(controller)

        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertTrue(controller.target === controller.rootView.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(120), 0)
        controller.updateWhileKeyboardFrameChanging(.zero)

        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
        window.isHidden = true
    }

    func testControllerForwardsButtonActions() throws {
        let (controller, output) = try makeController()

        controller.rootView.nominatorView.sendActions(for: .touchUpInside)
        controller.rootView.bouncerView.sendActions(for: .touchUpInside)
        controller.rootView.rootAccountView.sendActions(for: .touchUpInside)
        controller.rootView.feeView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.nominatorTaps, 1)
        XCTAssertEqual(output.bouncerTaps, 1)
        XCTAssertEqual(output.rootTaps, 1)
        XCTAssertEqual(output.createTaps, 1)
        XCTAssertEqual(output.backTaps, 1)
    }

    func testControllerBindsViewModelAndFee() throws {
        let (controller, _) = try makeController()

        controller.didReceiveViewModel(viewModel(poolId: 3))
        controller.didReceiveFeeViewModel(BalanceViewModel(amount: "0.01 DOT", price: "$0.05"))

        XCTAssertEqual(controller.rootView.poolIdView.text, "3")
        XCTAssertEqual(controller.rootView.nominatorView.subtitle, "Nominator wallet")
        XCTAssertEqual(controller.rootView.feeView.networkFeeView?.tokenLabel.text, "0.01 DOT")
        XCTAssertEqual(controller.rootView.feeView.networkFeeView?.fiatLabel?.text, "$0.05")
    }

    func testControllerEnablesActionOnlyWithAmountAndName() throws {
        let (controller, output) = try makeController()
        let chainAsset = CovCPJFixtures.chainAsset()
        let factory = CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: CovCPJFixtures.wallet())
        let nameViewModel = InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))

        controller.didReceive(nameViewModel: nameViewModel)
        controller.didReceiveAmountInputViewModel(factory.createBalanceInputViewModel(5).value(for: CovCPJFixtures.locale))
        controller.didReceiveAssetBalanceViewModel(
            factory.createAssetBalanceViewModel(5, balance: 10, priceData: nil).value(for: CovCPJFixtures.locale)
        )

        XCTAssertEqual(controller.rootView.amountView.textField.text, "5")
        XCTAssertFalse(controller.rootView.feeView.actionButton.isEnabled)

        let field = controller.rootView.poolNameInputView.animatedInputField
        let applied = controller.animatedTextField(
            field,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "My pool"
        )

        XCTAssertTrue(applied)
        XCTAssertEqual(nameViewModel.inputHandler.value, "My pool")
        XCTAssertEqual(output.nameChanges, 1)
        XCTAssertTrue(controller.rootView.feeView.actionButton.isEnabled)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(field))
    }

    func testControllerNameFieldWithoutViewModelAcceptsInput() throws {
        let (controller, output) = try makeController()

        let applied = controller.animatedTextField(
            controller.rootView.poolNameInputView.animatedInputField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: "x"
        )

        XCTAssertTrue(applied)
        XCTAssertEqual(output.nameChanges, 0)
    }

    func testControllerAmountTypingNotifiesOutput() throws {
        let (controller, output) = try makeController()
        let chainAsset = CovCPJFixtures.chainAsset()
        let factory = CovCPJFixtures.balanceFactory(chainAsset: chainAsset, wallet: CovCPJFixtures.wallet())
        let field = controller.rootView.amountView.textField

        XCTAssertFalse(controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1"))

        controller.didReceiveAmountInputViewModel(factory.createBalanceInputViewModel(nil).value(for: CovCPJFixtures.locale))
        _ = controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "7")

        XCTAssertEqual(output.amounts.last, 7)
        XCTAssertEqual(field.text, "7")
    }

    func testControllerAccessoryViewForwardsPercentage() throws {
        let (controller, output) = try makeController()
        let accessory = try XCTUnwrap(controller.rootView.amountView.textField.inputAccessoryView as? AmountInputAccessoryView)

        accessory.actionSelect50()
        accessory.actionSelectDone()

        XCTAssertEqual(output.percentages, [0.5])
    }

    func testControllerApplyLocalizationUpdatesRootLocale() throws {
        let (controller, _) = try makeController()

        controller.rootView.locale = Locale(identifier: "ru")
        controller.applyLocalization()

        XCTAssertEqual(controller.rootView.locale.identifier, controller.selectedLocale.identifier)
        XCTAssertEqual(
            controller.rootView.poolNameInputView.title,
            R.string.localizable.poolStakingPoolName(preferredLanguages: controller.selectedLocale.rLanguages)
        )
    }
}
