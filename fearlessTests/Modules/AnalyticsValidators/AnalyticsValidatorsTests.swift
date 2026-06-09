import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class AnalyticsValidatorsTests: XCTestCase {
    func testSetup_whenCalled_thenShowsLoadingAndSetsUpInteractor() {
        let fixture = makeFixture()
        let view = AnalyticsValidatorsViewSpy()
        fixture.presenter.view = view

        fixture.presenter.setup()

        XCTAssertEqual(view.receivedStates, [.loading])
        XCTAssertTrue(fixture.interactor.didSetup)
    }

    func testReload_whenCalled_thenShowsLoadingAndReloadsInteractor() {
        let fixture = makeFixture()
        let view = AnalyticsValidatorsViewSpy()
        fixture.presenter.view = view

        fixture.presenter.reload()

        XCTAssertEqual(view.receivedStates, [.loading])
        XCTAssertTrue(fixture.interactor.didReload)
    }

    func testHandleValidatorInfoAction_whenAddressSelected_thenRoutesToValidatorInfo() {
        let fixture = makeFixture()
        let view = AnalyticsValidatorsViewSpy()
        fixture.presenter.view = view

        fixture.presenter.handleValidatorInfoAction(validatorAddress: "validator-address")

        XCTAssertTrue(fixture.wireframe.view === view)
        XCTAssertEqual(fixture.wireframe.chainAsset?.chain.chainId, fixture.chain.chainId)
        XCTAssertEqual(fixture.wireframe.chainAsset?.asset.id, fixture.asset.id)
        XCTAssertEqual(fixture.wireframe.wallet?.identifier, fixture.account.identifier)

        guard case let .relaychain(_, address) = fixture.wireframe.flow else {
            XCTFail("Expected relaychain validator flow")
            return
        }

        XCTAssertEqual(address, "validator-address")
    }

    func testChartSelection_whenValidatorOrInactiveSegmentSelected_thenUpdatesCenterText() {
        let fixture = makeFixture()
        let view = AnalyticsValidatorsViewSpy()
        fixture.presenter.view = view
        let validator = AnalyticsValidatorItemViewModel(
            icon: nil,
            validatorName: "Validator",
            amount: 1.0,
            progressPercents: 0.5,
            mainValueText: "50%",
            secondaryValueText: "1 era",
            progressFullDescription: "50% (1 era)",
            validatorAddress: "validator-address"
        )
        let inactiveSegment = AnalyticsValidatorsViewModel.InactiveSegment(
            percents: 0.25,
            eraCount: 2
        )

        fixture.presenter.handleChartSelectedValidator(validator)
        fixture.presenter.handleChartSelectedInactiveSegment(inactiveSegment)

        XCTAssertEqual(view.chartCenterTexts.map(\.string), ["validator center", "inactive center"])
        XCTAssertEqual(fixture.viewModelFactory.selectedValidator?.validatorAddress, "validator-address")
        XCTAssertEqual(fixture.viewModelFactory.selectedInactiveSegment, inactiveSegment)
    }

    private func makeFixture() -> AnalyticsValidatorsFixture {
        let interactor = AnalyticsValidatorsInteractorInputSpy()
        let wireframe = AnalyticsValidatorsWireframeSpy()
        let viewModelFactory = AnalyticsValidatorsViewModelFactorySpy()
        let asset = ChainModelGenerator.generateAssetWithId("asset-id", symbol: "dot")
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let account = AccountGenerator.generateMetaAccount(with: [])
        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: LoggerSpy(),
            asset: asset,
            chain: chain,
            selectedAccount: account
        )

        return AnalyticsValidatorsFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            asset: asset,
            chain: chain,
            account: account
        )
    }
}

private struct AnalyticsValidatorsFixture {
    let presenter: AnalyticsValidatorsPresenter
    let interactor: AnalyticsValidatorsInteractorInputSpy
    let wireframe: AnalyticsValidatorsWireframeSpy
    let viewModelFactory: AnalyticsValidatorsViewModelFactorySpy
    let asset: AssetModel
    let chain: ChainModel
    let account: MetaAccountModel
}

private final class AnalyticsValidatorsViewSpy: AnalyticsValidatorsViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let localizedTitle = LocalizableResource<String> { _ in "Validators" }

    private(set) var receivedStates: [AnalyticsViewState<AnalyticsValidatorsViewModel>] = []
    private(set) var chartCenterTexts: [NSAttributedString] = []

    func reload(viewState: AnalyticsViewState<AnalyticsValidatorsViewModel>) {
        receivedStates.append(viewState)
    }

    func updateChartCenterText(_ text: NSAttributedString) {
        chartCenterTexts.append(text)
    }
}

private final class AnalyticsValidatorsInteractorInputSpy: AnalyticsValidatorsInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didReload = false

    func setup() {
        didSetup = true
    }

    func reload() {
        didReload = true
    }
}

private final class AnalyticsValidatorsWireframeSpy: AnalyticsValidatorsWireframeProtocol {
    private(set) var chainAsset: ChainAsset?
    private(set) var wallet: MetaAccountModel?
    private(set) var flow: ValidatorInfoFlow?
    private(set) weak var view: ControllerBackedProtocol?

    func showValidatorInfo(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow,
        view: ControllerBackedProtocol?
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.flow = flow
        self.view = view
    }
}

private final class AnalyticsValidatorsViewModelFactorySpy: AnalyticsValidatorsViewModelFactoryProtocol {
    private(set) var selectedValidator: AnalyticsValidatorItemViewModel?
    private(set) var selectedInactiveSegment: AnalyticsValidatorsViewModel.InactiveSegment?
    private(set) var requestedPage: AnalyticsValidatorsPage?

    func createViewModel(
        eraValidatorInfos _: [SubqueryEraValidatorInfo],
        eraRange _: EraRange,
        stashAddress _: AccountAddress,
        rewards _: [SubqueryRewardItemData],
        nomination _: Nomination,
        identitiesByAddress _: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage,
        locale _: Locale
    ) -> AnalyticsValidatorsViewModel {
        requestedPage = page
        return AnalyticsValidatorsViewModel(
            pieChartSegmentValues: [],
            pieChartInactiveSegment: nil,
            chartCenterText: NSAttributedString(string: "center"),
            listTitle: "Validators",
            validators: [],
            selectedPage: page
        )
    }

    func chartCenterText(validator: AnalyticsValidatorItemViewModel) -> NSAttributedString {
        selectedValidator = validator
        return NSAttributedString(string: "validator center")
    }

    func chartCenterTextInactiveSegment(
        _ inactiveSegment: AnalyticsValidatorsViewModel.InactiveSegment,
        locale _: Locale
    ) -> NSAttributedString {
        selectedInactiveSegment = inactiveSegment
        return NSAttributedString(string: "inactive center")
    }
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
