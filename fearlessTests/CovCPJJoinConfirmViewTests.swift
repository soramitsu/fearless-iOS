import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCPJJoinConfirmOutputDouble: StakingPoolJoinConfirmViewOutput {
    private(set) var loadedView: StakingPoolJoinConfirmViewInput?
    private(set) var confirmTaps = 0
    private(set) var backTaps = 0

    func didLoad(view: StakingPoolJoinConfirmViewInput) { loadedView = view }
    func didTapConfirmButton() { confirmTaps += 1 }
    func didTapBackButton() { backTaps += 1 }
}

final class CovCPJJoinConfirmViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func makeLayout() -> StakingPoolJoinConfirmViewLayout {
        let view = StakingPoolJoinConfirmViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()
        return view
    }

    private func viewModel(noValidators: Bool) -> StakingPoolJoinConfirmViewModel {
        StakingPoolJoinConfirmViewModel(
            amountAttributedString: NSAttributedString(string: "Stake 4 DOT"),
            accountNameString: "Wallet",
            accountAddressString: "5Address",
            selectedPoolName: "Alpha pool",
            poolHasNoValidators: noValidators
        )
    }

    private func makeFactory(chainAsset: ChainAsset) -> StakingPoolJoinConfirmViewModelFactory {
        StakingPoolJoinConfirmViewModelFactory(
            chainAsset: chainAsset,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
    }

    // MARK: - Layout

    func testLayoutLocalizesTitlesAndHidesHint() {
        let view = makeLayout()

        XCTAssertEqual(view.navigationBar.titleLabel.text, R.string.localizable.commonConfirm(preferredLanguages: languages))
        XCTAssertEqual(
            view.accountView.titleLabel.text,
            R.string.localizable.transactionDetailsFrom(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.selectedPoolView.titleLabel.text,
            R.string.localizable.poolStakingSelectedPool(preferredLanguages: languages)
        )
        XCTAssertEqual(view.feeView.titleLabel.text, R.string.localizable.commonNetworkFee(preferredLanguages: languages))
        XCTAssertEqual(
            view.continueButton.imageWithTitleView?.title,
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.hintView.detailsLabel.text,
            R.string.localizable.poolJoinNoValidatorsMessage(preferredLanguages: languages)
        )
        XCTAssertTrue(view.hintView.isHidden)
        XCTAssertTrue(view.accountView.borderView.isHidden)
        XCTAssertTrue(view.selectedPoolView.borderView.isHidden)
        XCTAssertEqual(view.accountView.valueBottom.lineBreakMode, .byTruncatingMiddle)
    }

    func testBindConfirmViewModelShowsHintWhenPoolHasNoValidators() {
        let view = makeLayout()

        view.bind(confirmViewModel: viewModel(noValidators: true))

        XCTAssertEqual(view.amountLabel.attributedText?.string, "Stake 4 DOT")
        XCTAssertEqual(view.accountView.valueTop.text, "Wallet")
        XCTAssertEqual(view.accountView.valueBottom.text, "5Address")
        XCTAssertEqual(view.selectedPoolView.valueTop.text, "Alpha pool")
        XCTAssertFalse(view.hintView.isHidden)

        view.bind(confirmViewModel: viewModel(noValidators: false))
        XCTAssertTrue(view.hintView.isHidden)
    }

    func testBindFeeViewModel() {
        let view = makeLayout()

        view.bind(feeViewModel: BalanceViewModel(amount: "0.4 DOT", price: nil))

        XCTAssertEqual(view.feeView.tokenLabel.text, "0.4 DOT")
        XCTAssertNil(view.feeView.fiatLabel)
    }

    // MARK: - View model factory

    func testFactoryBuildsAmountAddressAndPoolName() throws {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let wallet = CovCPJFixtures.wallet()
        let pool = CovCPJFixtures.pool(id: "3", name: "Alpha", points: 10, members: 1)

        let viewModel = makeFactory(chainAsset: chainAsset).buildViewModel(
            amount: 4,
            pool: pool,
            wallet: wallet,
            locale: CovCPJFixtures.locale,
            poolNomination: nil,
            nominationReceived: true
        )

        let expectedAddress = try XCTUnwrap(wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        XCTAssertEqual(viewModel.accountAddressString, expectedAddress)
        XCTAssertEqual(viewModel.accountNameString, wallet.name)
        XCTAssertEqual(viewModel.selectedPoolName, "Alpha")
        XCTAssertTrue(viewModel.poolHasNoValidators)
        XCTAssertTrue(viewModel.amountAttributedString.string.contains("4"))
    }

    func testFactoryValidatorsFlagAndNamelessPool() throws {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let wallet = CovCPJFixtures.wallet()
        let factory = makeFactory(chainAsset: chainAsset)
        let nameless = CovCPJFixtures.pool(id: "17", name: "", points: 10, members: 1)

        let withTargets = factory.buildViewModel(
            amount: 1,
            pool: nameless,
            wallet: wallet,
            locale: CovCPJFixtures.locale,
            poolNomination: try CovCPJFixtures.nomination(targetCount: 2),
            nominationReceived: true
        )
        let notReceived = factory.buildViewModel(
            amount: 1,
            pool: nameless,
            wallet: wallet,
            locale: CovCPJFixtures.locale,
            poolNomination: nil,
            nominationReceived: false
        )
        let emptyTargets = factory.buildViewModel(
            amount: 1,
            pool: nameless,
            wallet: wallet,
            locale: CovCPJFixtures.locale,
            poolNomination: try CovCPJFixtures.nomination(targetCount: 0),
            nominationReceived: true
        )

        XCTAssertEqual(withTargets.selectedPoolName, "17")
        XCTAssertFalse(withTargets.poolHasNoValidators)
        XCTAssertFalse(notReceived.poolHasNoValidators)
        XCTAssertTrue(emptyTargets.poolHasNoValidators)
    }

    // MARK: - View controller

    func testControllerLoadsBindsAndForwardsActions() throws {
        let output = CovCPJJoinConfirmOutputDouble()
        let controller = StakingPoolJoinConfirmViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        let window = CovCPJFixtures.host(controller)

        controller.didReceive(confirmViewModel: viewModel(noValidators: true))
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.1 DOT", price: "$2"))
        controller.applyLocalization()
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.continueButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertEqual(output.backTaps, 1)
        XCTAssertEqual(output.confirmTaps, 1)
        XCTAssertFalse(controller.rootView.hintView.isHidden)
        XCTAssertEqual(controller.rootView.selectedPoolView.valueTop.text, "Alpha pool")
        XCTAssertEqual(controller.rootView.feeView.fiatLabel?.text, "$2")
        XCTAssertEqual(
            controller.rootView.selectedPoolView.titleLabel.text,
            R.string.localizable.poolStakingSelectedPool(preferredLanguages: controller.selectedLocale.rLanguages)
        )
        window.isHidden = true
    }
}
