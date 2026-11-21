import XCTest
import SSFModels
import SSFUtils
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovCBPRDRecordingController: UIViewController {
    var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCBPRDViewDouble: StakingRewardDetailsViewProtocol {
    let recorder = CovCBPRDRecordingController()
    var viewModels: [LocalizableResource<StakingRewardDetailsViewModel>] = []

    var isSetup: Bool { true }
    var controller: UIViewController { recorder }

    func applyLocalization() {}
    func reload(with viewModel: LocalizableResource<StakingRewardDetailsViewModel>) { viewModels.append(viewModel) }
}

final class CovCBPRDWireframeDouble: StakingRewardDetailsWireframeProtocol {
    var payoutEras: [UInt32] = []

    func showPayoutConfirmation(
        from _: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel
    ) {
        payoutEras.append(payoutInfo.era)
    }
}

final class CovCBPRDInteractorDouble: StakingRewardDetailsInteractorInputProtocol {}

final class CovCBPRDPresenterDouble: StakingRewardDetailsPresenterProtocol {
    var setupCount = 0
    var payoutCount = 0
    var validatorLocales: [Locale] = []

    func setup() { setupCount += 1 }
    func handlePayoutAction() { payoutCount += 1 }
    func handleValidatorAccountAction(locale: Locale) { validatorLocales.append(locale) }
}

final class CovCBPRewardDetailsTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]

    private lazy var chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private lazy var asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private lazy var wallet = AccountGenerator.generateMetaAccount()
    private lazy var balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
    private let validatorId = Data(repeating: 7, count: 32)

    private func makeFactory() -> StakingRewardDetailsViewModelFactory {
        StakingRewardDetailsViewModelFactory(balanceViewModelFactory: balanceFactory, iconGenerator: UniversalIconGenerator())
    }

    private func makeInput(identity: AccountIdentity?) -> StakingRewardDetailsInput {
        StakingRewardDetailsInput(
            payoutInfo: PayoutInfo(era: 100, validator: validatorId, reward: 2.5, identity: identity),
            chain: chain,
            activeEra: 103,
            historyDepth: 84
        )
    }

    private func expectedDate(daysAgo: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return formatter.string(from: date)
    }

    // MARK: - View model factory

    func testFactoryBuildsRowsWithIdentityAndPrice() throws {
        let factory = makeFactory()
        let price = PriceData(currencyId: "usd", priceId: "dot", price: "4", fiatDayChange: nil, coingeckoPriceId: nil)
        let rows = factory.createViewModel(
            input: makeInput(identity: AccountIdentity(name: "Child", parentName: "Parent")),
            priceData: price
        ).value(for: locale).rows

        XCTAssertEqual(rows.count, 4)

        guard case let .validatorInfo(validator) = rows[0] else { return XCTFail("validator row expected") }
        XCTAssertEqual(validator.title, R.string.localizable.stakingRewardDetailsValidator(preferredLanguages: languages))
        XCTAssertEqual(validator.name, "Parent / Child")
        XCTAssertEqual(validator.address, factory.validatorAddress(from: validatorId, addressPrefix: 0))
        XCTAssertNotNil(validator.icon)

        guard case let .date(date) = rows[1] else { return XCTFail("date row expected") }
        XCTAssertEqual(date.titleText, R.string.localizable.stakingRewardDetailsDate(preferredLanguages: languages))
        XCTAssertEqual(date.valueText, expectedDate(daysAgo: 3))

        guard case let .era(era) = rows[2] else { return XCTFail("era row expected") }
        XCTAssertEqual(era.titleText, R.string.localizable.stakingRewardDetailsEra(preferredLanguages: languages))
        XCTAssertEqual(era.valueText, "#100")

        guard case let .reward(reward) = rows[3] else { return XCTFail("reward row expected") }
        XCTAssertEqual(reward.title, R.string.localizable.stakingRewardDetailsReward(preferredLanguages: languages))
        XCTAssertEqual(reward.tokenAmountText, balanceFactory.amountFromValue(2.5, usageCase: .detailsCrypto).value(for: locale))
        XCTAssertFalse(reward.usdAmountText?.isEmpty ?? true)
    }

    func testFactoryFallsBackToAddressWithoutIdentityOrPrice() throws {
        let factory = makeFactory()
        let rows = factory.createViewModel(input: makeInput(identity: nil), priceData: nil).value(for: locale).rows

        guard case let .validatorInfo(validator) = rows[0] else { return XCTFail("validator row expected") }
        let address = try XCTUnwrap(factory.validatorAddress(from: validatorId, addressPrefix: 0))
        XCTAssertEqual(validator.name, address)

        guard case let .reward(reward) = rows[3] else { return XCTFail("reward row expected") }
        XCTAssertEqual(reward.usdAmountText, "")
    }

    func testFactoryValidatorAddressVariants() {
        let factory = makeFactory()
        let byPrefix = factory.validatorAddress(from: validatorId, addressPrefix: 0)
        let byType = factory.validatorAddress(from: validatorId, addressType: SNAddressType(rawValue: 0) ?? .polkadotMain)

        XCTAssertNotNil(byPrefix)
        XCTAssertEqual(byPrefix, byType)
        XCTAssertNotEqual(factory.validatorAddress(from: Data([1, 2, 3]), addressPrefix: 0), byPrefix)
    }

    // MARK: - Presenter

    private func makePresenter(identity: AccountIdentity? = nil, validator: Data? = nil)
        -> (StakingRewardDetailsPresenter, CovCBPRDViewDouble, CovCBPRDWireframeDouble) {
        var input = makeInput(identity: identity)
        if let validator = validator {
            input = StakingRewardDetailsInput(
                payoutInfo: PayoutInfo(era: 100, validator: validator, reward: 1, identity: identity),
                chain: chain,
                activeEra: 103,
                historyDepth: 84
            )
        }
        let presenter = StakingRewardDetailsPresenter(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: wallet,
            input: input,
            viewModelFactory: makeFactory()
        )
        let view = CovCBPRDViewDouble()
        let wireframe = CovCBPRDWireframeDouble()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = CovCBPRDInteractorDouble()
        return (presenter, view, wireframe)
    }

    func testPresenterSetupReloadsViewAndRoutesPayout() throws {
        let (presenter, view, wireframe) = makePresenter(identity: AccountIdentity(name: "Val"))

        presenter.setup()
        let viewModel = try XCTUnwrap(view.viewModels.first).value(for: locale)
        XCTAssertEqual(viewModel.rows.count, 4)

        presenter.handlePayoutAction()
        XCTAssertEqual(wireframe.payoutEras, [100])
    }

    func testPresenterValidatorActionPresentsOptions() {
        let (presenter, view, _) = makePresenter()

        presenter.handleValidatorAccountAction(locale: locale)

        XCTAssertEqual(view.recorder.presentedControllers.count, 1)
        XCTAssertTrue(view.recorder.presentedControllers.first is UIAlertController)
    }

    func testPresenterValidatorActionWithoutViewDoesNothing() {
        let (presenter, view, wireframe) = makePresenter(validator: Data([9, 9]))

        presenter.view = nil
        presenter.handleValidatorAccountAction(locale: locale)
        presenter.setup()

        XCTAssertTrue(view.recorder.presentedControllers.isEmpty)
        XCTAssertTrue(view.viewModels.isEmpty)
        XCTAssertTrue(wireframe.payoutEras.isEmpty)
    }

    // MARK: - View controller and layout

    private func makeRows() -> LocalizableResource<StakingRewardDetailsViewModel> {
        LocalizableResource { _ in
            StakingRewardDetailsViewModel(rows: [
                .status(StakingRewardStatusViewModel(title: "Status", statusText: "Claimable", icon: nil)),
                .date(.init(titleText: "Date", valueText: "Jan 1, 2026")),
                .era(.init(titleText: "Era", valueText: "#5")),
                .reward(.init(title: "Reward", tokenAmountText: "1 DOT", usdAmountText: "")),
                .validatorInfo(AccountInfoViewModel(title: "Validator", address: "5Val", name: "Val", icon: nil)),
                .destination(.init(titleText: "Destination", valueText: "Restake"))
            ])
        }
    }

    private func makeController() throws -> (StakingRewardDetailsViewController, CovCBPRDPresenterDouble) {
        let presenter = CovCBPRDPresenterDouble()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        return (StakingRewardDetailsViewController(presenter: presenter, localizationManager: manager), presenter)
    }

    func testControllerLoadsAndLocalizes() throws {
        let (controller, presenter) = try makeController()
        controller.loadViewIfNeeded()

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.title, R.string.localizable.stakingRewardDetailsTitle(preferredLanguages: languages))
        XCTAssertEqual(
            controller.rootView.payoutButton.imageWithTitleView?.title,
            R.string.localizable.stakingRewardDetailsPayout(preferredLanguages: languages)
        )
        XCTAssertTrue(controller.rootView.tableView.dataSource === controller)

        controller.rootView.payoutButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.payoutCount, 1)
    }

    func testControllerRendersEveryRowKind() throws {
        let (controller, presenter) = try makeController()
        controller.loadViewIfNeeded()
        let table = controller.rootView.tableView

        controller.reload(with: makeRows())
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 6)

        let status = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? StakingPayoutStatusTableCell)
        XCTAssertEqual(status.statusLabel.text, "Claimable")
        let date = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? StakingPayoutLabelTableCell)
        XCTAssertEqual(date.valueLabel.text, "Jan 1, 2026")
        let era = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0)) as? StakingPayoutLabelTableCell)
        XCTAssertEqual(era.valueLabel.text, "#5")
        let reward = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 3, section: 0)) as? StakingPayoutRewardTableCell)
        XCTAssertEqual(reward.tokenAmountLabel.text, "1 DOT")
        let account = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 4, section: 0)) as? AccountInfoTableViewCell)
        XCTAssertEqual(account.detailsView.subtitle, "Val")
        let plain = controller.tableView(table, cellForRowAt: IndexPath(row: 5, section: 0))
        XCTAssertFalse(plain is StakingPayoutLabelTableCell)

        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 4, section: 0)), 82.0)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 1, section: 0)), 48.0)

        account.actionDetails()
        XCTAssertEqual(presenter.validatorLocales.map(\.identifier), ["en"])

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        controller.applyLocalization()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 6)
    }

    func testLayoutContainsTableAndButton() {
        let layout = StakingRewardDetailsViewLayout()
        layout.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        layout.layoutIfNeeded()

        XCTAssertTrue(layout.tableView.superview === layout)
        XCTAssertTrue(layout.payoutButton.superview === layout)
        XCTAssertGreaterThan(layout.payoutButton.frame.height, 0)
    }
}
