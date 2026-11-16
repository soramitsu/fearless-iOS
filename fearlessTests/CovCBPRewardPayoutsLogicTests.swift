import XCTest
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCBPRPLTimeFormatterStub: TimeFormatterProtocol {
    var requested: [TimeInterval] = []

    func string(from timeInterval: TimeInterval) throws -> String {
        requested.append(timeInterval)
        return "STUB-TIME"
    }
}

final class CovCBPRPLViewDouble: StakingRewardPayoutsViewProtocol {
    let backing = UIViewController()
    var states: [StakingRewardPayoutsViewState] = []

    var isSetup: Bool { true }
    var controller: UIViewController { backing }
    var loadableContentView: UIView { backing.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func didStartLoading() {}
    func didStopLoading() {}
    func applyLocalization() {}
    func reload(with state: StakingRewardPayoutsViewState) { states.append(state) }
}

final class CovCBPRPLWireframeDouble: StakingRewardPayoutsWireframeProtocol {
    var detailsEras: [UInt32] = []
    var detailsHistoryDepths: [UInt32] = []
    var confirmationPayoutCounts: [Int] = []

    func showRewardDetails(
        from _: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra _: EraIndex,
        historyDepth: UInt32,
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel
    ) {
        detailsEras.append(payoutInfo.era)
        detailsHistoryDepths.append(historyDepth)
    }

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chainAsset _: ChainAsset,
        wallet _: fearless.MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        confirmationPayoutCounts.append(payouts.count)
    }
}

final class CovCBPRPLInteractorDouble: StakingRewardPayoutsInteractorInputProtocol {
    var setupCount = 0
    var reloadCount = 0

    func setup() { setupCount += 1 }
    func reload() { reloadCount += 1 }
}

final class CovCBPRewardPayoutsLogicTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    private let languages = ["en"]

    private lazy var chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private lazy var asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private lazy var wallet = AccountGenerator.generateMetaAccount()
    private lazy var balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)

    private func makeFactory(formatter: TimeFormatterProtocol = CovCBPRPLTimeFormatterStub()) -> StakingPayoutViewModelFactory {
        StakingPayoutViewModelFactory(chain: chain, balanceViewModelFactory: balanceFactory, timeFormatter: formatter)
    }

    private func makeCountdown() -> EraCountdown {
        EraCountdown(
            activeEra: 110,
            currentEra: 110,
            eraLength: 6,
            sessionLength: 600,
            activeEraStartSessionIndex: 1000,
            currentSessionIndex: 1002,
            currentSlot: 1002 * 600 + 100,
            genesisSlot: 0,
            blockCreationTime: 6000,
            createdAtDate: Date()
        )
    }

    private func makePayouts(historyDepth: UInt32 = 84) -> PayoutsInfo {
        PayoutsInfo(
            activeEra: 110,
            historyDepth: historyDepth,
            payouts: [
                PayoutInfo(era: 100, validator: Data(repeating: 1, count: 32), reward: 1.5, identity: AccountIdentity(name: "Val")),
                PayoutInfo(era: 90, validator: Data(repeating: 2, count: 32), reward: 0.5, identity: nil),
                PayoutInfo(era: 20, validator: Data(repeating: 3, count: 32), reward: 0.25, identity: nil),
                PayoutInfo(era: 26, validator: Data(repeating: 4, count: 32), reward: 0.75, identity: nil)
            ]
        )
    }

    private func color(of string: NSAttributedString) -> UIColor? {
        guard string.length > 0 else { return nil }
        return string.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
    }

    private func sameColor(_ lhs: UIColor?, _ rhs: UIColor?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return false }
        var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
        var rr: CGFloat = 0, rg: CGFloat = 0, rb: CGFloat = 0, ra: CGFloat = 0
        lhs.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
        rhs.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
        return abs(lr - rr) < 0.01 && abs(lg - rg) < 0.01 && abs(lb - rb) < 0.01 && abs(la - ra) < 0.01
    }

    // MARK: - StakingPayoutViewModelFactory

    func testCreatePayoutsViewModelWithCountdown() throws {
        let formatter = CovCBPRPLTimeFormatterStub()
        let factory = makeFactory(formatter: formatter)
        let price = PriceData(currencyId: "usd", priceId: "dot", price: "10", fiatDayChange: nil, coingeckoPriceId: nil)

        let viewModel = factory.createPayoutsViewModel(
            payoutsInfo: makePayouts(),
            priceData: price,
            eraCountdown: makeCountdown(),
            erasPerDay: 1
        ).value(for: locale)

        XCTAssertEqual(viewModel.cellViewModels.count, 4)
        XCTAssertEqual(viewModel.cellViewModels[0].addressOrName, "Val")
        XCTAssertFalse(viewModel.cellViewModels[1].addressOrName.isEmpty)
        XCTAssertNotEqual(viewModel.cellViewModels[1].addressOrName, viewModel.cellViewModels[2].addressOrName)
        XCTAssertTrue(viewModel.cellViewModels[0].tokenAmountText.hasPrefix("+"))
        XCTAssertNotNil(viewModel.cellViewModels[0].usdAmountText)

        let expectedDays = R.string.localizable.commonDaysLeftFormat(format: 18, format: 18, preferredLanguages: languages)
        XCTAssertEqual(viewModel.cellViewModels[0].daysLeftText.string, expectedDays)
        XCTAssertTrue(sameColor(color(of: viewModel.cellViewModels[0].daysLeftText), R.color.colorRed()))
        XCTAssertEqual(
            viewModel.cellViewModels[2].daysLeftText.string,
            R.string.localizable.stakingPayoutExpired(preferredLanguages: languages)
        )
        XCTAssertEqual(
            viewModel.cellViewModels[3].daysLeftText.string,
            R.string.localizable.commonTimeLeftFormat("STUB-TIME", preferredLanguages: languages)
        )
        XCTAssertFalse(formatter.requested.isEmpty)

        let completion = try XCTUnwrap(viewModel.eraComletionTime)
        XCTAssertGreaterThan(completion, 18 * 86400)

        let total = balanceFactory.amountFromValue(3.0, usageCase: .listCrypto).value(for: locale)
        XCTAssertEqual(viewModel.bottomButtonTitle, R.string.localizable.stakingRewardPayoutsPayoutAll(total, preferredLanguages: languages))
    }

    func testCreatePayoutsViewModelWithoutCountdownOrPrice() {
        let viewModel = makeFactory().createPayoutsViewModel(
            payoutsInfo: makePayouts(historyDepth: 2),
            priceData: nil,
            eraCountdown: nil,
            erasPerDay: 1
        ).value(for: locale)

        XCTAssertNil(viewModel.eraComletionTime)
        XCTAssertNil(viewModel.cellViewModels[0].usdAmountText)
        XCTAssertEqual(viewModel.cellViewModels[0].daysLeftText.string, "")
        XCTAssertEqual(viewModel.cellViewModels[0].locale, locale)
    }

    func testTimeLeftStringUsesLightColorWhenFarFromExpiry() {
        let factory = makeFactory()
        let text = factory.timeLeftString(at: 0, payoutsInfo: makePayouts(), eraCountdown: makeCountdown(), erasPerDay: 100)
            .value(for: locale)

        XCTAssertEqual(text.string, R.string.localizable.commonDaysLeftFormat(format: 18, format: 18, preferredLanguages: languages))
        XCTAssertTrue(sameColor(color(of: text), R.color.colorLightGray()))

        let empty = factory.timeLeftString(at: 1, payoutsInfo: makePayouts(), eraCountdown: nil, erasPerDay: 1).value(for: locale)
        XCTAssertEqual(empty.string, "")
    }

    // MARK: - StakingRewardPayoutsPresenter

    private func makePresenter() -> (StakingRewardPayoutsPresenter, CovCBPRPLViewDouble, CovCBPRPLWireframeDouble, CovCBPRPLInteractorDouble) {
        let presenter = StakingRewardPayoutsPresenter(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: wallet,
            viewModelFactory: makeFactory()
        )
        let view = CovCBPRPLViewDouble()
        let wireframe = CovCBPRPLWireframeDouble()
        let interactor = CovCBPRPLInteractorDouble()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        return (presenter, view, wireframe, interactor)
    }

    private func isLoading(_ state: StakingRewardPayoutsViewState?, _ expected: Bool) -> Bool {
        if case let .loading(value) = state { return value == expected }
        return false
    }

    func testPresenterSetupAndReloadShowLoading() {
        let (presenter, view, _, interactor) = makePresenter()

        presenter.setup()
        presenter.reload()

        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(interactor.reloadCount, 1)
        XCTAssertEqual(view.states.count, 2)
        XCTAssertTrue(isLoading(view.states.first, true))
        XCTAssertTrue(isLoading(view.states.last, true))
    }

    func testPresenterBeforeDataIgnoresActions() {
        let (presenter, view, wireframe, _) = makePresenter()

        presenter.handleSelectedHistory(at: 0)
        presenter.handlePayoutAction()
        presenter.didReceive(eraCountdownResult: .success(makeCountdown()))

        XCTAssertNil(presenter.getTimeLeftString(at: 0))
        XCTAssertTrue(wireframe.detailsEras.isEmpty)
        XCTAssertTrue(wireframe.confirmationPayoutCounts.isEmpty)
        XCTAssertTrue(view.states.isEmpty)
    }

    func testPresenterShowsPayoutsAndRoutes() throws {
        let (presenter, view, wireframe, _) = makePresenter()

        presenter.didReceive(result: .success(makePayouts()))

        XCTAssertTrue(isLoading(view.states.first, false))
        guard case let .payoutsList(resource) = try XCTUnwrap(view.states.last) else {
            return XCTFail("expected payouts list")
        }
        XCTAssertEqual(resource.value(for: locale).cellViewModels.count, 4)

        presenter.didReceive(eraCountdownResult: .success(makeCountdown()))
        guard case let .payoutsList(withCountdown) = try XCTUnwrap(view.states.last) else {
            return XCTFail("expected payouts list")
        }
        XCTAssertNotNil(withCountdown.value(for: locale).eraComletionTime)

        presenter.didReceive(eraCountdownResult: .failure(PayoutRewardsServiceError.unknown))
        guard case let .payoutsList(withoutCountdown) = try XCTUnwrap(view.states.last) else {
            return XCTFail("expected payouts list")
        }
        XCTAssertNil(withoutCountdown.value(for: locale).eraComletionTime)

        presenter.handleSelectedHistory(at: 1)
        presenter.handleSelectedHistory(at: 10)
        presenter.handleSelectedHistory(at: -1)
        XCTAssertEqual(wireframe.detailsEras, [90])
        XCTAssertEqual(wireframe.detailsHistoryDepths, [84])

        presenter.handlePayoutAction()
        XCTAssertEqual(wireframe.confirmationPayoutCounts, [4])

        XCTAssertNotNil(presenter.getTimeLeftString(at: 0))
    }

    func testPresenterShowsEmptyAndErrorStates() throws {
        let (presenter, view, wireframe, _) = makePresenter()

        presenter.didReceive(result: .success(PayoutsInfo(activeEra: 1, historyDepth: 84, payouts: [])))
        guard case .emptyList = try XCTUnwrap(view.states.last) else {
            return XCTFail("expected empty list")
        }

        presenter.didReceive(result: .failure(.unknown))
        guard case let .error(message) = try XCTUnwrap(view.states.last) else {
            return XCTFail("expected error")
        }
        XCTAssertEqual(message.value(for: locale), R.string.localizable.commonErrorNoDataRetrieved(preferredLanguages: languages))

        presenter.handlePayoutAction()
        XCTAssertTrue(wireframe.confirmationPayoutCounts.isEmpty)
        XCTAssertNil(presenter.getTimeLeftString(at: 0))
    }
}
