import XCTest
import UIKit
import SoraFoundation
import SSFModels
import FearlessWalletConnect
@testable import fearless

final class CovJProposalView: UIViewController, WalletConnectProposalViewInput {
    var models: [WalletConnectProposalViewModel] = []
    var loadingStarts = 0
    var loadingStops = 0
    var onModel: (() -> Void)?
    func didReceive(viewModel: WalletConnectProposalViewModel) { models.append(viewModel); onModel?() }
    func didStartLoading() { loadingStarts += 1 }
    func didStopLoading() { loadingStops += 1 }
}

final class CovJProposalInteractor: WalletConnectProposalInteractorInput {
    weak var output: WalletConnectProposalInteractorOutput?
    var decisions: [WalletConnectProposalDecision] = []
    var disconnected: [String] = []
    var error: Error?
    var onSubmit: (() -> Void)?
    func setup(with output: WalletConnectProposalInteractorOutput) { self.output = output }
    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        decisions.append(proposalDecision)
        onSubmit?()
        if let error { throw error }
    }
    func submitDisconnect(topic: String) async throws {
        disconnected.append(topic)
        if let error { throw error }
    }
}

final class CovJProposalRouter: WalletConnectProposalRouterInput {
    var dismissals = 0
    var completions: [String] = []
    var completion: (() -> Void)?
    var alerts: [SheetAlertPresentableViewModel] = []
    var selections: [(Bool, [ChainModel], [String]?)] = []
    var onDone: (() -> Void)?
    var onAlert: (() -> Void)?

    func dismiss(view: ControllerBackedProtocol?) { dismissals += 1 }
    func showAllDone(title: String, description: String, view: ControllerBackedProtocol?, closure: @escaping () -> Void) {
        completions.append(description)
        completion = closure
        onDone?()
    }
    func showMultiSelect(canSelect: Bool, dataSource: [ChainModel], selectedChains: [ChainModel.Id]?,
                         moduleOutput: MultiSelectNetworksModuleOutput?, view: ControllerBackedProtocol?) {
        selections.append((canSelect, dataSource, selectedChains))
    }
    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        alerts.append(viewModel)
        onAlert?()
    }
    func present(message: String?, title: String, closeAction: String?, from view: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        present(viewModel: SheetAlertPresentableViewModel(title: title, message: message, actions: actions, closeAction: closeAction), from: view)
    }
}

final class CovJWalletConnectPresenterTests: XCTestCase {
    private func makePresenter(status: WalletConnectProposalPresenter.SessionStatus,
                               resolver: CovJWalletConnectResolver,
                               interactor: CovJProposalInteractor, router: CovJProposalRouter) -> WalletConnectProposalPresenter {
        WalletConnectProposalPresenter(
            status: status, walletConnectModelFactory: resolver,
            viewModelFactory: WalletConnectProposalViewModelFactoryImpl(status: status, walletConnectModelFactory: resolver),
            dataValidatingFactory: WalletConnectProposalDataValidating(presentable: router), logger: Logger.shared,
            interactor: interactor, router: router, localizationManager: LocalizationManager.shared
        )
    }

    @MainActor func testProposalWaitsForDataRoutesNetworksAndApprovesSelectedWallets() async throws {
        let blockchain = try XCTUnwrap(Blockchain("eip155:1"))
        let optional = try XCTUnwrap(Blockchain("eip155:137"))
        let chain = CovJWalletConnectFixture.chain()
        let polygon = CovJWalletConnectFixture.chain(id: "137", name: "Polygon")
        let proposal = CovJWalletConnectFixture.proposal(
            required: ["eip155": ProposalNamespace(chains: [blockchain], methods: ["personal_sign"], events: [])],
            optional: ["eip155": ProposalNamespace(chains: [optional], methods: [], events: [])]
        )
        let resolver = CovJWalletConnectResolver()
        resolver.resolutions = ["eip155:1": chain, "eip155:137": polygon]
        let interactor = CovJProposalInteractor()
        let router = CovJProposalRouter()
        let presenter = makePresenter(status: .proposal(proposal), resolver: resolver, interactor: interactor, router: router)
        let view = CovJProposalView()
        let wallet = AccountGenerator.generateMetaAccount()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        presenter.didSelectRowAt(IndexPath(row: 0, section: 0))
        XCTAssertTrue(router.selections.isEmpty)
        presenter.didReceive(chainsResult: .success([chain, polygon]))
        XCTAssertTrue(view.models.isEmpty)
        let received = expectation(description: "Proposal model")
        view.onModel = { received.fulfill() }
        presenter.didReceive(walletsResult: .success([wallet]))
        await fulfillment(of: [received], timeout: 5)
        view.onModel = nil
        XCTAssertEqual(view.models.count, 1)
        presenter.didSelectRowAt(IndexPath(row: 0, section: 0))
        presenter.didSelectRowAt(IndexPath(row: 1, section: 0))
        presenter.didSelectRowAt(IndexPath(row: 3, section: 0))
        XCTAssertEqual(router.selections.count, 2)
        XCTAssertFalse(router.selections[0].0)
        XCTAssertEqual(router.selections[0].1.map(\.chainId), ["1"])
        XCTAssertEqual(router.selections[0].2, ["1"])
        XCTAssertTrue(router.selections[1].0)
        XCTAssertEqual(router.selections[1].2, ["137"])
        presenter.didSelectRowAt(IndexPath(row: 2, section: 0))
        guard case let .requiredExpandable(expanded) = try XCTUnwrap(view.models.last).cells[2] else {
            return XCTFail("Permission row should expand")
        }
        XCTAssertTrue(expanded.isExpanded)
        presenter.selectedChain(ids: [])
        let completed = expectation(description: "Approved")
        router.onDone = { completed.fulfill() }
        presenter.mainActionButtonDidTapped()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(interactor.decisions.count, 1)
        guard case .approve = interactor.decisions[0] else { return XCTFail("Expected approval") }
        XCTAssertEqual(resolver.approvedWallets.map(\.metaId), [wallet.metaId])
        XCTAssertEqual(resolver.optionalIds, [])
        XCTAssertEqual(view.loadingStops, 1)
        router.completion?()
        XCTAssertEqual(router.dismissals, 1)
        presenter.backButtonDidTapped()
        XCTAssertEqual(router.dismissals, 2)
    }

    @MainActor func testUnsupportedChainReportsErrorAndCloseDismisses() async {
        let resolver = CovJWalletConnectResolver()
        let proposal = CovJWalletConnectFixture.proposal(
            required: ["eip155": ProposalNamespace(chains: [Blockchain("eip155:1")].compactMap { $0 }, methods: [], events: [])]
        )
        let interactor = CovJProposalInteractor()
        let router = CovJProposalRouter()
        let presenter = makePresenter(status: .proposal(proposal), resolver: resolver, interactor: interactor, router: router)
        let view = CovJProposalView()
        presenter.didLoad(view: view)
        presenter.didReceive(walletsResult: .failure(NSError(domain: "fixture", code: 1)))
        presenter.didReceive(chainsResult: .failure(NSError(domain: "fixture", code: 1)))
        XCTAssertTrue(view.models.isEmpty)
        let failed = expectation(description: "Unsupported chains")
        router.onAlert = { failed.fulfill() }
        presenter.didReceive(chainsResult: .success([CovJWalletConnectFixture.chain()]))
        presenter.didReceive(walletsResult: .success([AccountGenerator.generateMetaAccount()]))
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertEqual(router.alerts.count, 1)
        XCTAssertEqual(router.alerts[0].message, AutoNamespacesError.requiredChainsNotSatisfied.localizedDescription)
        XCTAssertEqual(view.loadingStops, 1)
        router.alerts[0].dismissCompletion?()
        XCTAssertEqual(router.dismissals, 1)
    }

    @MainActor func testRejectAndDisappearSubmitRejections() async {
        let proposal = CovJWalletConnectFixture.proposal()
        let interactor = CovJProposalInteractor()
        let router = CovJProposalRouter()
        let presenter = makePresenter(status: .proposal(proposal), resolver: CovJWalletConnectResolver(), interactor: interactor, router: router)
        let view = CovJProposalView()
        presenter.didLoad(view: view)
        let done = expectation(description: "Rejected")
        router.onDone = { done.fulfill() }
        presenter.rejectButtonDidTapped()
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(interactor.decisions.count, 1)
        guard case .reject = interactor.decisions[0] else { return XCTFail("Expected reject") }
        XCTAssertEqual(router.completions, [R.string.localizable.commonRejected(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)])
        let disappeared = expectation(description: "Dismissal rejection")
        interactor.onSubmit = { disappeared.fulfill() }
        presenter.viewDidDisappear()
        await fulfillment(of: [disappeared], timeout: 5)
        XCTAssertEqual(interactor.decisions.count, 2)
    }

    @MainActor func testActiveSessionLoadsThenDisconnects() async {
        let session = CovJWalletConnectFixture.session()
        let resolver = CovJWalletConnectResolver()
        let interactor = CovJProposalInteractor()
        let router = CovJProposalRouter()
        let presenter = makePresenter(status: .active(session), resolver: resolver, interactor: interactor, router: router)
        let view = CovJProposalView()
        presenter.didLoad(view: view)
        let received = expectation(description: "Active session model")
        view.onModel = { received.fulfill() }
        presenter.didReceive(walletsResult: .success([AccountGenerator.generateMetaAccount()]))
        presenter.didReceive(chainsResult: .success([CovJWalletConnectFixture.chain()]))
        await fulfillment(of: [received], timeout: 5)
        XCTAssertEqual(view.models.count, 1)
        XCTAssertNotNil(view.models.first?.expiryDate)
        let done = expectation(description: "Disconnected")
        router.onDone = { done.fulfill() }
        presenter.mainActionButtonDidTapped()
        XCTAssertEqual(view.loadingStarts, 1)
        await fulfillment(of: [done], timeout: 5)
        XCTAssertEqual(interactor.disconnected, ["session"])
        XCTAssertEqual(view.loadingStops, 1)
        XCTAssertTrue(interactor.decisions.isEmpty)
    }

    @MainActor func testDisconnectFailureStopsLoadingAndDisplaysError() async {
        let interactor = CovJProposalInteractor()
        let error = NSError(domain: "fixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Connection unavailable"])
        interactor.error = error
        let router = CovJProposalRouter()
        let presenter = makePresenter(status: .active(CovJWalletConnectFixture.session()),
                                      resolver: CovJWalletConnectResolver(), interactor: interactor, router: router)
        let view = CovJProposalView()
        presenter.didLoad(view: view)
        let failed = expectation(description: "Disconnect failed")
        router.onAlert = { failed.fulfill() }
        presenter.mainActionButtonDidTapped()
        await fulfillment(of: [failed], timeout: 5)
        XCTAssertEqual(router.alerts.first?.message, "Connection unavailable")
        XCTAssertEqual(view.loadingStarts, 1)
        XCTAssertEqual(view.loadingStops, 1)
        XCTAssertTrue(router.completions.isEmpty)
    }

    func testUnsupportedMethodWarningCanApproveOrReject() {
        let router = CovJProposalRouter()
        let factory = WalletConnectProposalDataValidating(presentable: router)
        var approvals = 0
        var rejections = 0
        let runner = DataValidationRunner(validators: [
            factory.validate(requiredMethods: ["unsupported_method"], view: nil, locale: CovJWalletConnectFixture.locale) { rejections += 1 }
        ])
        runner.runValidation { approvals += 1 }
        XCTAssertEqual(approvals, 0)
        XCTAssertEqual(router.alerts.count, 1)
        XCTAssertEqual(router.alerts[0].actions.count, 2)
        router.alerts[0].actions[1].handler?()
        XCTAssertEqual(rejections, 1)
        XCTAssertEqual(approvals, 0)
        router.alerts[0].actions[0].handler?()
        XCTAssertEqual(approvals, 1)
    }
}
