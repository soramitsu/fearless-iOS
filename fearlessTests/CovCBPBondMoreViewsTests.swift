import XCTest
import SoraFoundation
@testable import fearless

final class CovCBPBondMoreViewPresenterDouble: StakingBondMorePresenterProtocol {
    var setupCount = 0
    var continueCount = 0
    var backCount = 0
    var amounts: [Decimal] = []
    var percentages: [Float] = []

    func setup() { setupCount += 1 }
    func handleContinueAction() { continueCount += 1 }
    func updateAmount(_ newValue: Decimal) { amounts.append(newValue) }
    func selectAmountPercentage(_ percentage: Float) { percentages.append(percentage) }
    func didTapBackButton() { backCount += 1 }
}

final class CovCBPBondMoreConfirmViewPresenterDouble: StakingBondMoreConfirmationPresenterProtocol {
    var setupCount = 0
    var confirmCount = 0
    var selectAccountCount = 0
    var backCount = 0

    func setup() { setupCount += 1 }
    func confirm() { confirmCount += 1 }
    func selectAccount() { selectAccountCount += 1 }
    func didTapBackButton() { backCount += 1 }
}

final class CovCBPBondMoreViewsTests: XCTestCase {
    private let languages = ["en"]

    private func makeManager() throws -> LocalizationManager {
        try XCTUnwrap(LocalizationManager(localization: "en"))
    }

    private func makeBalanceFactory() -> BalanceViewModelFactory {
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        return BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            selectedMetaAccount: AccountGenerator.generateMetaAccount()
        )
    }

    private func makeFeeViewModel(amount: String) -> LocalizableResource<NetworkFeeFooterViewModelProtocol> {
        let balance = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: amount, price: "$1") }
        return NetworkFeeViewModelFactory().createViewModel(from: balance)
    }

    // MARK: - NetworkFeeViewModelFactory

    func testNetworkFeeViewModelFactoryBuildsTitles() {
        let viewModel = makeFeeViewModel(amount: "0.3 DOT").value(for: Locale(identifier: "en"))

        XCTAssertEqual(viewModel.actionTitle.value(for: Locale(identifier: "en")), R.string.localizable.commonContinue(preferredLanguages: languages))
        XCTAssertEqual(viewModel.feeTitle.value(for: Locale(identifier: "en")), R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(viewModel.balanceViewModel.value(for: Locale(identifier: "en")).amount, "0.3 DOT")
        XCTAssertEqual(viewModel.balanceViewModel.value(for: Locale(identifier: "en")).price, "$1")
    }

    // MARK: - StakingBondMoreViewLayout

    func testBondMoreLayoutLocalizesAndBindsFee() {
        let layout = StakingBondMoreViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = Locale(identifier: "en")
        layout.layoutIfNeeded()

        XCTAssertTrue(layout.hintView.isHidden)
        XCTAssertEqual(layout.hintView.detailsLabel.text, R.string.localizable.stakingHintRewardBondMore(preferredLanguages: languages))
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.stakingBondMore_v190(preferredLanguages: languages))

        layout.bind(feeViewModel: makeFeeViewModel(amount: "0.01 DOT").value(for: Locale(identifier: "en")))
        XCTAssertEqual(
            layout.networkFeeFooterView.actionButton.imageWithTitleView?.title,
            R.string.localizable.commonContinue(preferredLanguages: languages)
        )
        XCTAssertNotNil(layout.networkFeeFooterView.networkFeeView)

        layout.bind(feeViewModel: nil)
        XCTAssertNil(layout.networkFeeFooterView.actionTitle)
    }

    // MARK: - StakingBondMoreViewController

    func testBondMoreControllerSetupAndActions() throws {
        let presenter = CovCBPBondMoreViewPresenterDouble()
        let controller = StakingBondMoreViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertTrue(controller.rootView.amountInputView.textField.delegate === controller)
        XCTAssertEqual(controller.selectedLocale.identifier, "en")

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.continueCount, 1)
        XCTAssertEqual(presenter.backCount, 1)

        let accessory = try XCTUnwrap(controller.rootView.amountInputView.textField.inputAccessoryView as? AmountInputAccessoryView)
        accessory.actionSelect50()
        accessory.actionSelectDone()
        XCTAssertEqual(presenter.percentages, [0.5])
    }

    func testBondMoreControllerHintsAndFee() throws {
        let presenter = CovCBPBondMoreViewPresenterDouble()
        let controller = StakingBondMoreViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        controller.didReceiveHints(viewModel: LocalizableResource { _ in "Hint text" })
        XCTAssertFalse(controller.rootView.hintView.isHidden)
        XCTAssertEqual(controller.rootView.hintView.detailsLabel.text, "Hint text")

        controller.didReceiveHints(viewModel: nil)
        XCTAssertTrue(controller.rootView.hintView.isHidden)

        controller.didReceiveFee(viewModel: makeFeeViewModel(amount: "0.02 DOT"))
        XCTAssertFalse(controller.rootView.networkFeeFooterView.actionButton.isEnabled)
        XCTAssertNotNil(controller.rootView.networkFeeFooterView.networkFeeView)

        controller.didReceiveFee(viewModel: nil)
        XCTAssertNil(controller.rootView.networkFeeFooterView.actionTitle)
    }

    func testBondMoreControllerInputAndAsset() throws {
        let presenter = CovCBPBondMoreViewPresenterDouble()
        let controller = StakingBondMoreViewController(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()
        let factory = makeBalanceFactory()

        controller.didReceiveInput(viewModel: factory.createBalanceInputViewModel(5))
        XCTAssertEqual(controller.rootView.amountInputView.inputFieldText, "5")
        XCTAssertTrue(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        let textField = controller.rootView.amountInputView.textField
        let allowed = controller.textField(textField, shouldChangeCharactersIn: NSRange(location: 1, length: 0), replacementString: "1")
        XCTAssertFalse(allowed)
        XCTAssertEqual(presenter.amounts.last, 51)
        XCTAssertEqual(controller.rootView.amountInputView.inputFieldText, "51")

        controller.didReceiveInput(viewModel: factory.createBalanceInputViewModel(nil))
        XCTAssertFalse(controller.rootView.networkFeeFooterView.actionButton.isEnabled)

        let asset = AssetBalanceViewModel(symbol: "dot", balance: "100", fiatBalance: nil, price: "$7", iconViewModel: nil, selectable: false)
        controller.didReceiveAsset(viewModel: LocalizableResource { _ in asset })
        XCTAssertEqual(controller.rootView.amountInputView.symbol, "DOT")
        XCTAssertEqual(controller.rootView.amountInputView.priceText, "$7")
        XCTAssertEqual(
            controller.rootView.amountInputView.balanceText,
            R.string.localizable.commonAvailableFormat("100", preferredLanguages: languages)
        )

        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
    }

    func testBondMoreControllerWithoutInputRejectsReplacement() throws {
        let presenter = CovCBPBondMoreViewPresenterDouble()
        let controller = StakingBondMoreViewController(presenter: presenter, localizationManager: nil)
        controller.loadViewIfNeeded()

        let textField = controller.rootView.amountInputView.textField
        XCTAssertFalse(controller.textField(textField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "1"))
        XCTAssertTrue(presenter.amounts.isEmpty)
        XCTAssertEqual(presenter.setupCount, 1)
    }

    // MARK: - StakingBMConfirmationViewLayout

    func testConfirmationLayoutLocalizesAndBinds() {
        let layout = StakingBMConfirmationViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.locale = Locale(identifier: "en")
        layout.layoutIfNeeded()

        XCTAssertEqual(layout.accountView.titleLabel.text, R.string.localizable.commonAccount(preferredLanguages: languages))
        XCTAssertEqual(layout.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(layout.amountView.titleLabel.text, R.string.localizable.walletSendAmountTitle(preferredLanguages: languages))
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.commonConfirmTitle(preferredLanguages: languages))
        XCTAssertEqual(layout.hintView.detailsLabel.text, R.string.localizable.stakingHintRewardBondMore(preferredLanguages: languages))

        layout.bind(confirmationViewModel: makeConfirmViewModel())
        XCTAssertEqual(layout.accountView.valueTop.text, "Wallet")
        XCTAssertEqual(layout.accountView.valueBottom.text, "5Address")
        XCTAssertEqual(layout.amountView.valueTop.text, "3 DOT")
        XCTAssertEqual(layout.amountView.valueBottom.text, "$9")
        XCTAssertEqual(layout.stakeAmountView.amountLabel.attributedText?.string, "Stake 3 DOT")

        layout.bind(feeViewModel: BalanceViewModel(amount: "0.4 DOT", price: nil))
        XCTAssertEqual(layout.feeView.valueTop.text, "0.4 DOT")

        let asset = AssetBalanceViewModel(symbol: "DOT", balance: nil, fiatBalance: nil, price: nil, iconViewModel: nil, selectable: true)
        layout.bind(assetViewModel: asset)
        layout.layoutSubviews()
        XCTAssertEqual(layout.navigationBar.backButton.layer.cornerRadius, layout.navigationBar.backButton.frame.size.height / 2)
    }

    private func makeConfirmViewModel(withAmount: Bool = true) -> StakingBondMoreConfirmViewModel {
        let amount: LocalizableResource<StakeAmountViewModel>? = withAmount ? LocalizableResource { _ in
            StakeAmountViewModel(amountTitle: NSAttributedString(string: "Stake 3 DOT"), iconViewModel: nil, color: nil)
        } : nil
        return StakingBondMoreConfirmViewModel(
            accountViewModel: TitleMultiValueViewModel(title: "Wallet", subtitle: "5Address"),
            amountViewModel: TitleMultiValueViewModel(title: "3 DOT", subtitle: "$9"),
            senderIcon: nil,
            amount: amount
        )
    }

    // MARK: - StakingBondMoreConfirmationVC

    func testConfirmationControllerSetupAndActions() throws {
        let presenter = CovCBPBondMoreConfirmViewPresenterDouble()
        let controller = StakingBondMoreConfirmationVC(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.selectedLocale.identifier, "en")

        controller.rootView.networkFeeFooterView.actionButton.sendActions(for: .touchUpInside)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.confirmCount, 1)
        XCTAssertEqual(presenter.backCount, 1)
    }

    func testConfirmationControllerReceivesViewModels() throws {
        let presenter = CovCBPBondMoreConfirmViewPresenterDouble()
        let controller = StakingBondMoreConfirmationVC(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        controller.didReceiveConfirmation(viewModel: makeConfirmViewModel(withAmount: false))
        XCTAssertEqual(controller.rootView.accountView.valueTop.text, "Wallet")
        XCTAssertTrue(controller.rootView.stakeAmountView.amountLabel.attributedText?.string.isEmpty ?? true)

        let fee = LocalizableResource<BalanceViewModelProtocol> { _ in BalanceViewModel(amount: "0.5 DOT", price: "$2") }
        controller.didReceiveFee(viewModel: fee)
        XCTAssertEqual(controller.rootView.feeView.valueTop.text, "0.5 DOT")
        XCTAssertEqual(controller.rootView.feeView.valueBottom.text, "$2")

        let asset = AssetBalanceViewModel(symbol: "DOT", balance: "1", fiatBalance: nil, price: nil, iconViewModel: nil, selectable: true)
        controller.didReceiveAsset(viewModel: LocalizableResource { _ in asset })

        controller.didReceiveConfirmation(viewModel: makeConfirmViewModel())
        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.amountView.valueTop.text, "3 DOT")
        XCTAssertEqual(controller.rootView.stakeAmountView.amountLabel.attributedText?.string, "Stake 3 DOT")

        controller.didReceiveFee(viewModel: nil)
        XCTAssertEqual(controller.rootView.feeView.valueTop.text, "0.5 DOT")
    }

    func testConfirmationControllerSealWithoutLoader() throws {
        let presenter = CovCBPBondMoreConfirmViewPresenterDouble()
        let controller = StakingBondMoreConfirmationVC(presenter: presenter, localizationManager: try makeManager())
        controller.loadViewIfNeeded()

        controller.didReachTransferStage(.ready)
        controller.didBreakTransfer()
        XCTAssertNil(FWTransferSeal.sealView(in: controller.view))
    }
}
