import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingRewardPayoutsTests: XCTestCase {
    func testSetupAndReload_thenShowsLoadingAndDelegatesToInteractor() {
        let fixture = makeFixture()

        fixture.presenter.setup()
        fixture.presenter.reload()

        XCTAssertEqual(fixture.view.loadingStates, [true, true])
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(fixture.interactor.didReload)
    }

    func testDidReceiveSuccess_whenPayoutsAvailable_thenShowsList() {
        let fixture = makeFixture()
        let payoutsInfo = makePayoutsInfo()

        fixture.presenter.didReceive(result: .success(payoutsInfo))

        XCTAssertEqual(fixture.view.loadingStates, [false])
        XCTAssertTrue(fixture.view.didReceivePayoutsList)
        XCTAssertEqual(fixture.viewModelFactory.lastPayouts?.payouts.count, 1)
    }

    func testDidReceiveSuccess_whenEmpty_thenShowsEmptyList() {
        let fixture = makeFixture()

        fixture.presenter.didReceive(result: .success(PayoutsInfo(activeEra: 10, historyDepth: 84, payouts: [])))

        XCTAssertTrue(fixture.view.didReceiveEmptyList)
    }

    func testDidReceiveFailure_thenShowsError() {
        let fixture = makeFixture()

        fixture.presenter.didReceive(result: .failure(.unknown))

        XCTAssertEqual(fixture.view.loadingStates, [false])
        XCTAssertTrue(fixture.view.didReceiveError)
    }

    func testEraCountdownAndTimeLeft_thenRefreshesListAndReturnsText() {
        let fixture = makeFixture()
        fixture.presenter.didReceive(result: .success(makePayoutsInfo()))

        fixture.presenter.didReceive(eraCountdownResult: .success(.testValue))
        let timeLeft = fixture.presenter.getTimeLeftString(at: 0)?.value(for: Locale.current).string

        XCTAssertTrue(fixture.view.didReceivePayoutsList)
        XCTAssertNotNil(fixture.viewModelFactory.lastEraCountdown)
        XCTAssertEqual(timeLeft, "time left")
    }

    func testActions_whenPayoutsAvailable_thenRouteDetailsAndConfirmation() {
        let fixture = makeFixture()
        fixture.presenter.didReceive(result: .success(makePayoutsInfo()))

        fixture.presenter.handleSelectedHistory(at: 0)
        fixture.presenter.handlePayoutAction()

        XCTAssertEqual(fixture.wireframe.rewardDetailsEra, 9)
        XCTAssertEqual(fixture.wireframe.confirmationPayoutCount, 1)
        XCTAssertEqual(fixture.wireframe.confirmationChainAssetId, fixture.chainAsset.identifier)
    }

    private func makeFixture() -> StakingRewardPayoutsFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = StakingRewardPayoutsInteractorInputSpy()
        let wireframe = StakingRewardPayoutsWireframeSpy()
        let viewModelFactory = StakingPayoutViewModelFactorySpy()
        let presenter = StakingRewardPayoutsPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )
        let view = StakingRewardPayoutsViewSpy()
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        return StakingRewardPayoutsFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset
        )
    }

    private func makePayoutsInfo() -> PayoutsInfo {
        PayoutsInfo(
            activeEra: 10,
            historyDepth: 84,
            payouts: [
                PayoutInfo(
                    era: 9,
                    validator: Data(repeating: 1, count: 32),
                    reward: 2,
                    identity: nil
                )
            ]
        )
    }

    private func makeChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }
}

private struct StakingRewardPayoutsFixture {
    let presenter: StakingRewardPayoutsPresenter
    let interactor: StakingRewardPayoutsInteractorInputSpy
    let wireframe: StakingRewardPayoutsWireframeSpy
    let view: StakingRewardPayoutsViewSpy
    let viewModelFactory: StakingPayoutViewModelFactorySpy
    let chainAsset: ChainAsset
}

private final class StakingRewardPayoutsInteractorInputSpy:
    StakingRewardPayoutsInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didReload = false

    func setup() {
        didSetup = true
    }

    func reload() {
        didReload = true
    }
}

private final class StakingRewardPayoutsViewSpy: StakingRewardPayoutsViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var loadingStates: [Bool] = []
    private(set) var didReceivePayoutsList = false
    private(set) var didReceiveEmptyList = false
    private(set) var didReceiveError = false

    func reload(with state: StakingRewardPayoutsViewState) {
        switch state {
        case let .loading(loading):
            loadingStates.append(loading)
        case .payoutsList:
            didReceivePayoutsList = true
        case .emptyList:
            didReceiveEmptyList = true
        case .error:
            didReceiveError = true
        }
    }

    func didStartLoading() {}

    func didStopLoading() {}

    func applyLocalization() {}
}

private final class StakingPayoutViewModelFactorySpy: StakingPayoutViewModelFactoryProtocol {
    private(set) var lastPayouts: PayoutsInfo?
    private(set) var lastEraCountdown: EraCountdown?

    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData _: PriceData?,
        eraCountdown: EraCountdown?,
        erasPerDay _: UInt32
    ) -> LocalizableResource<StakingPayoutViewModel> {
        lastPayouts = payoutsInfo
        lastEraCountdown = eraCountdown

        return LocalizableResource { _ in
            StakingPayoutViewModel(
                cellViewModels: [],
                eraComletionTime: nil,
                bottomButtonTitle: "Payout"
            )
        }
    }

    func timeLeftString(
        at _: Int,
        payoutsInfo _: PayoutsInfo,
        eraCountdown _: EraCountdown?,
        erasPerDay _: UInt32
    ) -> LocalizableResource<NSAttributedString> {
        LocalizableResource { _ in NSAttributedString(string: "time left") }
    }
}

private final class StakingRewardPayoutsWireframeSpy: StakingRewardPayoutsWireframeProtocol {
    private(set) var rewardDetailsEra: EraIndex?
    private(set) var confirmationPayoutCount: Int?
    private(set) var confirmationChainAssetId: String?

    func showRewardDetails(
        from _: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra _: EraIndex,
        historyDepth _: UInt32,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        rewardDetailsEra = payoutInfo.era
    }

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        confirmationPayoutCount = payouts.count
        confirmationChainAssetId = chainAsset.identifier
    }
}

private extension EraCountdown {
    static var testValue: EraCountdown {
        EraCountdown(
            activeEra: 10,
            currentEra: 10,
            eraLength: 6,
            sessionLength: 10,
            activeEraStartSessionIndex: 1,
            currentSessionIndex: 1,
            currentSlot: 11,
            genesisSlot: 0,
            blockCreationTime: 6_000,
            createdAtDate: Date()
        )
    }
}
