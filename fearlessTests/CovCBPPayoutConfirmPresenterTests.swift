import XCTest
import BigInt
import SSFModels
import SoraFoundation
@testable import fearless

final class CovCBPPCPRecordingController: UIViewController {
    var presentedControllers: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
    }
}

final class CovCBPPCPViewDouble: StakingPayoutConfirmationViewProtocol, FWTransferSealShowing {
    let recorder = CovCBPPCPRecordingController()
    var feeViewModels: [LocalizableResource<BalanceViewModelProtocol>?] = []
    var listViewModels: [[LocalizableResource<PayoutConfirmViewModel>]] = []
    var singleViewModels: [StakingPayoutConfirmationViewModel?] = []
    var loadingEvents: [String] = []
    var sealEvents: [String] = []

    var isSetup: Bool { true }
    var controller: UIViewController { recorder }
    var loadableContentView: UIView { recorder.view }
    var shouldDisableInteractionWhenLoading: Bool { false }

    func applyLocalization() {}
    func didStartLoading() { loadingEvents.append("start") }
    func didStopLoading() { loadingEvents.append("stop") }
    func didRecieve(viewModel: [LocalizableResource<PayoutConfirmViewModel>]) { listViewModels.append(viewModel) }
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) { feeViewModels.append(feeViewModel) }
    func didReceive(singleViewModel: StakingPayoutConfirmationViewModel?) { singleViewModels.append(singleViewModel) }
    func didReachTransferStage(_ stage: FWSealStage) { sealEvents.append("stage-\(stage)") }
    func didBreakTransfer() { sealEvents.append("break") }
}

final class CovCBPPCPWireframeDouble: StakingPayoutConfirmationWireframeProtocol {
    var completeCount = 0
    var dismissCount = 0
    var presentedErrors: [Error] = []
    var errorHandled = false

    func complete(from _: StakingPayoutConfirmationViewProtocol?) { completeCount += 1 }
    func dismiss(view _: ControllerBackedProtocol?) { dismissCount += 1 }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return errorHandled
    }
}

final class CovCBPPCPInteractorDouble: StakingPayoutConfirmationInteractorInputProtocol {
    var setupCount = 0
    var estimateClosures: [ExtrinsicBuilderClosure?] = []
    var submitClosures: [ExtrinsicBuilderClosure?] = []

    func setup() { setupCount += 1 }
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) { estimateClosures.append(builderClosure) }
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) { submitClosures.append(builderClosure) }
}

final class CovCBPPCPAuthorizerStub: SubmissionAuthorizing {
    var allow = true
    var requests = 0

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(allow)
    }
}

final class CovCBPPCPStateStub: StakingPayoutConfirmationViewModelState {
    var stateListener: StakingPayoutConfirmationModelStateListener?
    var fee: Decimal?
    var builderClosure: ExtrinsicBuilderClosure?
    var validatorsResult: [DataValidating] = []

    func setStateListener(_ stateListener: StakingPayoutConfirmationModelStateListener?) {
        self.stateListener = stateListener
    }

    func validators(using _: Locale) -> [DataValidating] { validatorsResult }
}

final class CovCBPPCPFactoryStub: StakingPayoutConfirmationViewModelFactoryProtocol {
    var listCalls = 0
    var singleCalls = 0

    func createPayoutConfirmViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>] {
        listCalls += 1
        return [LocalizableResource { _ in .restakeDestination(.init(titleText: "t", valueText: "v")) }]
    }

    func createSinglePayoutConfirmationViewModel(
        viewModelState _: StakingPayoutConfirmationViewModelState,
        priceData _: PriceData?
    ) -> StakingPayoutConfirmationViewModel? {
        singleCalls += 1
        return StakingPayoutConfirmationViewModel(
            senderAddress: "5Addr",
            senderIcon: nil,
            senderName: "Name",
            amount: nil,
            amountString: LocalizableResource { _ in "1" }
        )
    }
}

final class CovCBPPCPStrategyDouble: StakingPayoutConfirmationStrategy {
    var calls: [String] = []

    func setup() { calls.append("setup") }
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?) { calls.append(builderClosure == nil ? "fee-nil" : "fee") }
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?) { calls.append(builderClosure == nil ? "submit-nil" : "submit") }
}

final class CovCBPPayoutConfirmPresenterTests: XCTestCase {
    private struct CovCEnv {
        let presenter: StakingPayoutConfirmationPresenter
        let view: CovCBPPCPViewDouble
        let wireframe: CovCBPPCPWireframeDouble
        let interactor: CovCBPPCPInteractorDouble
        let state: CovCBPPCPStateStub
        let factory: CovCBPPCPFactoryStub
        let authorizer: CovCBPPCPAuthorizerStub
    }

    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()

    private func makeEnv() -> CovCEnv {
        let state = CovCBPPCPStateStub()
        let factory = CovCBPPCPFactoryStub()
        let authorizer = CovCBPPCPAuthorizerStub()
        let wireframe = CovCBPPCPWireframeDouble()
        let balanceFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo, selectedMetaAccount: wallet)
        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceFactory,
            payoutConfirmViewModelFactory: factory,
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            logger: nil,
            viewModelState: state,
            wallet: wallet,
            submissionAuthorizer: authorizer
        )
        let view = CovCBPPCPViewDouble()
        let interactor = CovCBPPCPInteractorDouble()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        return CovCEnv(
            presenter: presenter,
            view: view,
            wireframe: wireframe,
            interactor: interactor,
            state: state,
            factory: factory,
            authorizer: authorizer
        )
    }

    func testSetupProvidesEmptyFeeAndStartsInteractor() {
        let env = makeEnv()
        env.state.builderClosure = { builder in builder }

        env.presenter.setup()

        XCTAssertTrue(env.state.stateListener === env.presenter)
        XCTAssertEqual(env.view.feeViewModels.count, 1)
        XCTAssertNil(env.view.feeViewModels.first ?? nil)
        XCTAssertEqual(env.interactor.setupCount, 1)
        XCTAssertEqual(env.interactor.estimateClosures.count, 1)
        XCTAssertNotNil(env.interactor.estimateClosures.first ?? nil)
    }

    func testProvideFeeAndViewModels() throws {
        let env = makeEnv()
        env.state.fee = 0.25

        env.presenter.provideFee()
        let fee = try XCTUnwrap(env.view.feeViewModels.last ?? nil)
        XCTAssertFalse(fee.value(for: Locale(identifier: "en")).amount.isEmpty)

        env.presenter.provideViewModel()
        XCTAssertEqual(env.factory.listCalls, 1)
        XCTAssertEqual(env.factory.singleCalls, 1)
        XCTAssertEqual(env.view.listViewModels.first?.count, 1)
        XCTAssertEqual(env.view.singleViewModels.first??.senderName, "Name")
    }

    func testProceedSubmitsWhenAuthorized() {
        let env = makeEnv()
        env.state.builderClosure = { builder in builder }

        env.presenter.proceed()
        XCTAssertEqual(env.authorizer.requests, 1)
        XCTAssertEqual(env.interactor.submitClosures.count, 1)

        env.authorizer.allow = false
        env.presenter.proceed()
        XCTAssertEqual(env.authorizer.requests, 2)
        XCTAssertEqual(env.interactor.submitClosures.count, 1)
    }

    func testProceedStopsOnFailedValidation() {
        let env = makeEnv()
        let factory = StakingDataValidatingFactory(presentable: env.wireframe)
        env.state.validatorsResult = [factory.has(fee: nil, locale: Locale(identifier: "en"), onError: nil)]

        env.presenter.proceed()

        XCTAssertEqual(env.authorizer.requests, 0)
        XCTAssertTrue(env.interactor.submitClosures.isEmpty)
    }

    func testAccountOptionsAndBack() {
        let env = makeEnv()
        let account = AccountInfoViewModel(title: "Account", address: "5Address", name: "Name", icon: nil)

        env.presenter.presentAccountOptions(for: account)
        XCTAssertEqual(env.view.recorder.presentedControllers.count, 1)
        XCTAssertTrue(env.view.recorder.presentedControllers.first is UIAlertController)

        env.presenter.didTapBackButton()
        XCTAssertEqual(env.wireframe.dismissCount, 1)

        env.presenter.view = nil
        env.presenter.presentAccountOptions(for: account)
        XCTAssertEqual(env.view.recorder.presentedControllers.count, 1)
    }

    func testPayoutLifecycleEvents() {
        let env = makeEnv()

        env.presenter.didStartPayout()
        XCTAssertEqual(env.view.loadingEvents, ["start"])
        XCTAssertEqual(env.view.sealEvents, ["stage-\(FWSealStage.ready)"])

        env.presenter.didCompletePayout(txHashes: ["0x1", "0x2"])
        XCTAssertEqual(env.view.loadingEvents, ["start", "stop"])
        XCTAssertEqual(env.view.sealEvents.last, "stage-\(FWSealStage.accepted)")
        XCTAssertEqual(env.wireframe.completeCount, 1)

        env.presenter.didCompletePayout(txHashes: [])
        XCTAssertEqual(env.view.sealEvents.count, 2)
        XCTAssertEqual(env.wireframe.completeCount, 2)

        env.presenter.didCompletePayout(result: .success("0xhash"))
        XCTAssertEqual(env.wireframe.completeCount, 3)
        XCTAssertEqual(env.view.sealEvents.last, "stage-\(FWSealStage.accepted)")

        env.presenter.didReceiveError(error: CommonError.undefined)
        XCTAssertEqual(env.wireframe.completeCount, 3)
    }

    func testFailuresPresentErrors() {
        let env = makeEnv()

        env.presenter.didCompletePayout(result: .failure(CommonError.network))
        XCTAssertEqual(env.view.sealEvents, ["break"])
        XCTAssertEqual(env.wireframe.presentedErrors.count, 2)
        XCTAssertEqual(env.view.loadingEvents, ["stop"])

        env.wireframe.errorHandled = true
        env.presenter.didFailPayout(error: CommonError.network)
        XCTAssertEqual(env.view.sealEvents, ["break", "break"])
        XCTAssertEqual(env.wireframe.presentedErrors.count, 3)
        XCTAssertEqual(env.wireframe.completeCount, 0)
    }

    func testInteractorForwardsToStrategy() {
        let strategy = CovCBPPCPStrategyDouble()
        let interactor = StakingPayoutConfirmationInteractor(strategy: strategy)

        interactor.setup()
        interactor.estimateFee(builderClosure: nil)
        interactor.submitPayout(builderClosure: { builder in builder })

        XCTAssertEqual(strategy.calls, ["setup", "fee-nil", "submit"])
    }
}
