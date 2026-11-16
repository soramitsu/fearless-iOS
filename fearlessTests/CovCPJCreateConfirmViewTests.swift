import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCPJCreateConfirmOutputDouble: StakingPoolCreateConfirmViewOutput {
    private(set) var loadedView: StakingPoolCreateConfirmViewInput?
    private(set) var backTaps = 0
    private(set) var confirmTaps = 0

    func didLoad(view: StakingPoolCreateConfirmViewInput) { loadedView = view }
    func didTapBackButton() { backTaps += 1 }
    func didTapConfirmButton() { confirmTaps += 1 }
}

final class CovCPJCreateConfirmViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func makeLayout() -> StakingPoolCreateConfirmViewLayout {
        let view = StakingPoolCreateConfirmViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func confirmViewModel(price: String?) -> StakingPoolCreateConfirmViewModel {
        StakingPoolCreateConfirmViewModel(
            amount: NSAttributedString(string: "Creating pool with 10 DOT"),
            amountString: "10 DOT",
            price: price,
            rootName: "Root",
            poolId: "12",
            nominatorName: "Nominator",
            bouncerName: "Bouncer"
        )
    }

    // MARK: - Layout

    func testLayoutLocalizesTitles() {
        let view = makeLayout()

        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonConfirm(preferredLanguages: languages))
        XCTAssertEqual(
            view.accountView.titleLabel.text,
            R.string.localizable.transactionDetailsFrom(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.amountView.titleLabel.text,
            R.string.localizable.walletSendAssetTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.accountView.valueTop.text,
            R.string.localizable.stakingPoolCreateManagementAccount(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.poolIdView.titleLabel.text,
            R.string.localizable.stakingPoolCreatePoolId(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.depositorView.titleLabel.text,
            R.string.localizable.stakingPoolCreateDepositor(preferredLanguages: languages)
        )
        XCTAssertEqual(view.rootView.titleLabel.text, R.string.localizable.stakingPoolCreateRoot(preferredLanguages: languages))
        XCTAssertEqual(
            view.nominatorView.titleLabel.text,
            R.string.localizable.stakingPoolCreateNominator(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.bouncerView.titleLabel.text,
            R.string.localizable.stakingPoolCreateStateToggler(preferredLanguages: languages)
        )
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(
            view.continueButton.imageWithTitleView?.title,
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        )
    }

    func testLayoutConfiguresMultiViews() {
        let view = makeLayout()

        XCTAssertEqual(view.multiViews.count, 7)
        XCTAssertTrue(view.multiViews.allSatisfy { $0.borderView.isHidden })
        XCTAssertTrue(view.multiViews.allSatisfy { $0.valueTop.textAlignment == .right })
        XCTAssertTrue(view.multiViews.allSatisfy { $0.superview === view.infoViewsStackView })
        XCTAssertTrue(view.feeView.superview === view.infoViewsStackView)
        XCTAssertNotNil(view.iconImageView.image)
    }

    func testBindConfirmViewModelFillsValues() {
        let view = makeLayout()

        view.bind(confirmViewModel: confirmViewModel(price: "$20"))

        XCTAssertEqual(view.amountLabel.attributedText?.string, "Creating pool with 10 DOT")
        XCTAssertEqual(view.accountView.valueBottom.text, "Root")
        XCTAssertEqual(view.amountView.valueTop.text, "10 DOT")
        XCTAssertEqual(view.amountView.valueBottom.text, "$20")
        XCTAssertEqual(view.poolIdView.valueTop.text, "12")
        XCTAssertEqual(view.depositorView.valueTop.text, "Root")
        XCTAssertEqual(view.rootView.valueTop.text, "Root")
        XCTAssertEqual(view.nominatorView.valueTop.text, "Nominator")
        XCTAssertEqual(view.bouncerView.valueTop.text, "Bouncer")
    }

    func testBindFeeViewModel() {
        let view = makeLayout()

        view.bind(feeViewModel: BalanceViewModel(amount: "0.2 DOT", price: "$1"))
        XCTAssertEqual(view.feeView.tokenLabel.text, "0.2 DOT")
        XCTAssertEqual(view.feeView.fiatLabel?.text, "$1")

        view.bind(feeViewModel: nil)
        XCTAssertNil(view.feeView.tokenLabel.text)
    }

    // MARK: - View model factory

    func testFactoryBuildsAmountAndPrice() {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let factory = StakingPoolCreateConfirmViewModelFactory(
            chainAsset: chainAsset,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let data = CreatePoolConfirmData(
            amount: 12,
            price: CovCPJFixtures.price("2"),
            currency: Currency.defaultCurrency(),
            rootName: "Root",
            poolId: "5",
            nominatorName: "Nominator",
            bouncerName: "Bouncer"
        )

        let viewModel = factory.buildViewModel(data: data, locale: CovCPJFixtures.locale)

        XCTAssertTrue(viewModel.amountString.contains("12"))
        XCTAssertEqual(
            viewModel.amount.string,
            R.string.localizable.stakingPoolCreateCreatingPool(viewModel.amountString, preferredLanguages: languages)
        )
        XCTAssertTrue(viewModel.price?.contains("24") ?? false)
        XCTAssertEqual(viewModel.poolId, "5")
        XCTAssertEqual(viewModel.rootName, "Root")
        XCTAssertEqual(viewModel.nominatorName, "Nominator")
        XCTAssertEqual(viewModel.bouncerName, "Bouncer")
    }

    func testFactoryOmitsPriceWhenMissingOrInvalid() {
        let factory = StakingPoolCreateConfirmViewModelFactory(
            chainAsset: CovCPJFixtures.chainAsset(precision: 10),
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let withoutPrice = CreatePoolConfirmData(
            amount: 1,
            price: nil,
            currency: Currency.defaultCurrency(),
            rootName: "R",
            poolId: "1",
            nominatorName: "N",
            bouncerName: "B"
        )
        let invalidPrice = CreatePoolConfirmData(
            amount: 1,
            price: CovCPJFixtures.price("not-a-number"),
            currency: Currency.defaultCurrency(),
            rootName: "R",
            poolId: "1",
            nominatorName: "N",
            bouncerName: "B"
        )

        XCTAssertNil(factory.buildViewModel(data: withoutPrice, locale: CovCPJFixtures.locale).price)
        XCTAssertNil(factory.buildViewModel(data: invalidPrice, locale: CovCPJFixtures.locale).price)
    }

    // MARK: - View controller

    func testControllerLoadsAndForwardsActions() throws {
        let output = CovCPJCreateConfirmOutputDouble()
        let controller = StakingPoolCreateConfirmViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )

        controller.loadViewIfNeeded()
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.continueButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertEqual(output.backTaps, 1)
        XCTAssertEqual(output.confirmTaps, 1)
    }

    func testControllerBindsViewModelsAndLocalization() throws {
        let controller = StakingPoolCreateConfirmViewController(
            output: CovCPJCreateConfirmOutputDouble(),
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        let window = CovCPJFixtures.host(controller)

        controller.didReceive(confirmViewModel: confirmViewModel(price: nil))
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.3 DOT", price: nil))
        controller.applyLocalization()

        XCTAssertEqual(controller.rootView.poolIdView.valueTop.text, "12")
        XCTAssertNil(controller.rootView.amountView.valueBottom.text)
        XCTAssertEqual(controller.rootView.feeView.tokenLabel.text, "0.3 DOT")
        XCTAssertEqual(
            controller.rootView.continueButton.imageWithTitleView?.title,
            R.string.localizable.commonConfirm(preferredLanguages: controller.selectedLocale.rLanguages)
        )
        window.isHidden = true
    }

    func testControllerLoadingIndicator() throws {
        let controller = StakingPoolCreateConfirmViewController(
            output: CovCPJCreateConfirmOutputDouble(),
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()
        let identifier = LoadableViewProtocolConstants.activityIndicatorIdentifier

        controller.didStartLoading()
        XCTAssertTrue(controller.view.subviews.contains { $0.accessibilityIdentifier == identifier })
        XCTAssertFalse(controller.view.isUserInteractionEnabled)

        controller.didStopLoading()
        XCTAssertFalse(controller.view.subviews.contains { $0.accessibilityIdentifier == identifier })
        XCTAssertTrue(controller.view.isUserInteractionEnabled)
    }
}
