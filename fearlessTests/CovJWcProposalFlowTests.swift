import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
import FearlessWalletConnect
@testable import fearless

final class CovJWcProposalViewSpy: UIViewController, WalletConnectProposalViewInput {
    private(set) var models: [WalletConnectProposalViewModel] = []
    private(set) var starts = 0
    private(set) var stops = 0

    func didReceive(viewModel: WalletConnectProposalViewModel) { models.append(viewModel) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJWcProposalInteractorStub: WalletConnectProposalInteractorInput {
    weak var output: WalletConnectProposalInteractorOutput?
    let decisions = CovJWcCalls<WalletConnectProposalDecision>()
    let disconnects = CovJWcCalls<String>()
    var failure: Error?

    func setup(with output: WalletConnectProposalInteractorOutput) { self.output = output }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        decisions.append(proposalDecision)
        if let failure { throw failure }
    }

    func submitDisconnect(topic: String) async throws {
        disconnects.append(topic)
        if let failure { throw failure }
    }
}

/// Implements every sheet requirement itself, so warnings with actions are recorded rather than presented.
final class CovJWcProposalRouterSpy: WalletConnectProposalRouterInput {
    private(set) var dismissals = 0
    private(set) var completions: [(title: String, description: String, closure: () -> Void)] = []
    private(set) var selections: [(canSelect: Bool, chains: [String], selected: [String]?)] = []
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var warnings: [(message: String?, title: String, closeAction: String?, actions: [SheetAlertPresentableAction])] = []
    private(set) var errors: [Error] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func showAllDone(title: String, description: String, view _: ControllerBackedProtocol?, closure: @escaping () -> Void) {
        completions.append((title, description, closure))
    }

    func showMultiSelect(
        canSelect: Bool,
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        moduleOutput _: MultiSelectNetworksModuleOutput?,
        view _: ControllerBackedProtocol?
    ) {
        selections.append((canSelect, dataSource.map(\.chainId), selectedChains))
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        warnings.append((message, title, closeAction, actions))
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }
}

final class CovJWcResolverStub: WalletConnectModelFactory {
    var resolutions: [String: ChainModel] = [:]
    var namespaces: [String: SessionNamespace] = [:]
    var namespaceError: Error?
    let approvedWalletIds = CovJWcCalls<[String]>()
    let optionalIds = CovJWcCalls<[String]?>()

    func createSessionNamespaces(
        from _: Session.Proposal,
        wallets: [MetaAccountModel],
        chains _: [ChainModel],
        optionalChainIds: [ChainModel.Id]?
    ) throws -> [String: SessionNamespace] {
        approvedWalletIds.append(wallets.map(\.metaId))
        optionalIds.append(optionalChainIds)
        if let namespaceError { throw namespaceError }
        return namespaces
    }

    func resolveChain(for blockchain: Blockchain, chains _: [ChainModel]) throws -> ChainModel {
        guard let chain = resolutions[blockchain.absoluteString] else { throw CovJError("unresolved") }
        return chain
    }

    func resolveChains(for blockchains: Set<Blockchain>, chains _: [ChainModel]) -> [ChainModel] {
        blockchains.sorted { $0.absoluteString < $1.absoluteString }.compactMap { resolutions[$0.absoluteString] }
    }

    func parseMethod(from request: Request) throws -> WalletConnectMethod {
        guard let method = WalletConnectMethod(rawValue: request.method) else { throw CovJError("method") }
        return method
    }
}

/// A view-model factory whose active-session model is fixed or fails, to reach the presenter's other branches.
final class CovJWcProposalFactoryStub: WalletConnectProposalViewModelFactory {
    var activeResult: Result<WalletConnectProposalViewModel, Error>

    init(activeResult: Result<WalletConnectProposalViewModel, Error>) {
        self.activeResult = activeResult
    }

    func buildProposalSessionViewModel(proposal _: Session.Proposal, chains _: [ChainModel], wallets _: [MetaAccountModel], locale _: Locale) throws
        -> WalletConnectProposalViewModel {
        try activeResult.get()
    }

    func buildActiveSessionViewModel(session _: Session, chains _: [ChainModel], wallets _: [MetaAccountModel], locale _: Locale) throws
        -> WalletConnectProposalViewModel {
        try activeResult.get()
    }

    func didTapOn(_: IndexPath, cells _: [WalletConnectProposalCellModel]) -> WalletConnectProposalViewModel? { nil }
}

final class CovJWcProposalPresenterTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    private func makePresenter(
        status: WalletConnectProposalPresenter.SessionStatus,
        resolver: CovJWcResolverStub,
        interactor: CovJWcProposalInteractorStub,
        router: CovJWcProposalRouterSpy,
        factory: WalletConnectProposalViewModelFactory? = nil
    ) throws -> WalletConnectProposalPresenter {
        WalletConnectProposalPresenter(
            status: status,
            walletConnectModelFactory: resolver,
            viewModelFactory: factory ?? WalletConnectProposalViewModelFactoryImpl(status: status, walletConnectModelFactory: resolver),
            dataValidatingFactory: WalletConnectProposalDataValidating(presentable: router),
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: try CovJWcFixture.localization()
        )
    }

    private func loadedProposal(
        methods: [String],
        resolver: CovJWcResolverStub,
        interactor: CovJWcProposalInteractorStub,
        router: CovJWcProposalRouterSpy
    ) throws -> (WalletConnectProposalPresenter, CovJWcProposalViewSpy, Session.Proposal, MetaAccountModel) {
        let chain = CovJWcFixture.evmChain()
        resolver.resolutions = ["eip155:1": chain]
        let proposal = CovJWcFixture.proposal(
            required: ["eip155": ProposalNamespace(chains: [try CovJWcFixture.blockchain()], methods: Set(methods), events: [])]
        )
        let presenter = try makePresenter(status: .proposal(proposal), resolver: resolver, interactor: interactor, router: router)
        let view = CovJWcProposalViewSpy()
        let wallet = AccountGenerator.generateMetaAccount()
        presenter.didLoad(view: view)
        presenter.didReceive(chainsResult: .success([chain]))
        presenter.didReceive(walletsResult: .success([wallet, AccountGenerator.generateMetaAccount()]))
        XCTAssertTrue(CovJWait.until(timeout: 5) { view.models.count == 1 })
        return (presenter, view, proposal, wallet)
    }

    func testUnsupportedMethodWarningCanRejectTheProposal() throws {
        let resolver = CovJWcResolverStub()
        let interactor = CovJWcProposalInteractorStub()
        let router = CovJWcProposalRouterSpy()
        let (presenter, view, _, _) = try loadedProposal(
            methods: ["personal_sign", "wallet_switchEthereumChain"], resolver: resolver, interactor: interactor, router: router
        )
        presenter.mainActionButtonDidTapped()
        let warning = try XCTUnwrap(router.warnings.first)
        XCTAssertEqual(warning.message, R.string.localizable.requiredMethodsNotSatisfied(preferredLanguages: languages))
        XCTAssertEqual(warning.title, "")
        XCTAssertNil(warning.closeAction)
        XCTAssertEqual(
            warning.actions.map(\.title),
            [R.string.localizable.commonApprove(preferredLanguages: languages), R.string.localizable.commonReject(preferredLanguages: languages)]
        )
        XCTAssertEqual(interactor.decisions.count, 0, "Nothing is sent before the warning is answered")

        warning.actions[1].handler?()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.completions.count == 1 })
        guard case .reject = try XCTUnwrap(interactor.decisions.all.first) else { return XCTFail("Expected a rejection") }
        XCTAssertEqual(router.completions[0].title, R.string.localizable.allDoneAlertAllDoneStub(preferredLanguages: languages))
        XCTAssertEqual(router.completions[0].description, R.string.localizable.commonRejected(preferredLanguages: languages))
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(resolver.approvedWalletIds.count, 0)
        router.completions[0].closure()
        XCTAssertEqual(router.dismissals, 1)
    }

    func testUnsupportedMethodWarningCanStillApproveTheFirstWallet() throws {
        let resolver = CovJWcResolverStub()
        let interactor = CovJWcProposalInteractorStub()
        let router = CovJWcProposalRouterSpy()
        let (presenter, _, proposal, wallet) = try loadedProposal(
            methods: ["wallet_addEthereumChain"], resolver: resolver, interactor: interactor, router: router
        )
        presenter.mainActionButtonDidTapped()
        let warning = try XCTUnwrap(router.warnings.first)
        warning.actions[0].handler?()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.completions.count == 1 })
        XCTAssertEqual(resolver.approvedWalletIds.all, [[wallet.metaId]])
        XCTAssertEqual(resolver.optionalIds.all.first ?? nil, [])
        guard case let .approve(approved, namespaces) = try XCTUnwrap(interactor.decisions.all.first) else {
            return XCTFail("Expected an approval")
        }
        XCTAssertEqual(approved.id, proposal.id)
        XCTAssertTrue(namespaces.isEmpty)
        XCTAssertEqual(
            router.completions[0].description,
            R.string.localizable.walletConnectConnectionComplete("Uniswap", preferredLanguages: languages)
        )
    }

    func testApprovalFailureIsShownAndClosingItDismisses() throws {
        let resolver = CovJWcResolverStub()
        resolver.namespaceError = NSError(domain: "covj", code: 3, userInfo: [NSLocalizedDescriptionKey: "Namespaces invalid"])
        let interactor = CovJWcProposalInteractorStub()
        let router = CovJWcProposalRouterSpy()
        let (presenter, view, _, _) = try loadedProposal(methods: ["personal_sign"], resolver: resolver, interactor: interactor, router: router)
        presenter.mainActionButtonDidTapped()
        XCTAssertTrue(router.warnings.isEmpty, "Supported methods need no warning")
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        let sheet = router.sheets[0]
        XCTAssertEqual(sheet.title, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, "Namespaces invalid")
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonClose(preferredLanguages: languages))
        XCTAssertEqual(interactor.decisions.count, 0)
        XCTAssertEqual(view.stops, 1)
        sheet.dismissCompletion?()
        XCTAssertEqual(router.dismissals, 1)
    }

    func testRejectionFailureShowsTheRelayMessage() throws {
        let resolver = CovJWcResolverStub()
        let interactor = CovJWcProposalInteractorStub()
        interactor.failure = FearlessWalletConnect.JSONRPCError(code: 5000, message: "Proposal expired")
        let router = CovJWcProposalRouterSpy()
        let presenter = try makePresenter(status: .proposal(CovJWcFixture.proposal()), resolver: resolver, interactor: interactor, router: router)
        let view = CovJWcProposalViewSpy()
        presenter.didLoad(view: view)
        presenter.rejectButtonDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        XCTAssertEqual(router.sheets[0].message, "Proposal expired")
        XCTAssertEqual(interactor.decisions.count, 1)
        XCTAssertTrue(router.completions.isEmpty)
        XCTAssertEqual(view.stops, 1)
    }

    func testActiveSessionModelFailureAndNetworkRowsWithoutAProposal() throws {
        let resolver = CovJWcResolverStub()
        let interactor = CovJWcProposalInteractorStub()
        let router = CovJWcProposalRouterSpy()
        let factory = CovJWcProposalFactoryStub(activeResult: .failure(CovJError("no permissions")))
        let session = CovJWcFixture.session()
        let presenter = try makePresenter(status: .active(session), resolver: resolver, interactor: interactor, router: router, factory: factory)
        let view = CovJWcProposalViewSpy()
        presenter.didLoad(view: view)
        presenter.didReceive(chainsResult: .success([CovJWcFixture.evmChain()]))
        presenter.didReceive(walletsResult: .success([AccountGenerator.generateMetaAccount()]))
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        XCTAssertEqual(router.sheets[0].message, CovJError("no permissions").localizedDescription)
        XCTAssertTrue(view.models.isEmpty)

        let details = WalletConnectProposalCellModel.DetailsViewModel(title: "Networks", subtitle: "Ethereum", icon: nil)
        factory.activeResult = .success(
            WalletConnectProposalViewModel(
                indexPath: nil, cells: [.requiredNetworks(details), .optionalNetworks(details), .dAppInfo(details)], expiryDate: "soon"
            )
        )
        presenter.didReceive(chainsResult: .success([CovJWcFixture.evmChain()]))
        XCTAssertTrue(CovJWait.until(timeout: 5) { view.models.count == 1 })
        XCTAssertEqual(view.models[0].expiryDate, "soon")
        for row in 0 ..< 4 {
            presenter.didSelectRowAt(IndexPath(row: row, section: 0))
        }
        XCTAssertTrue(router.selections.isEmpty, "An active session has no proposal networks to list")
        XCTAssertEqual(view.models.count, 1)
        presenter.selectedChain(ids: ["1"])
        presenter.applyLocalization()
        presenter.viewDidDisappear()
        CovJWait.drain()
        XCTAssertEqual(interactor.decisions.count, 0, "Leaving an active session sends no proposal decision")
    }
}

final class CovJWcProposalModuleTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    func testInteractorLoadsWalletsAndChainsAndForwardsDecisions() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJWcFixture.evmChain()
        let service = CovJWcServiceStub()
        let interactor = WalletConnectProposalInteractor(
            walletConnect: service,
            walletRepository: AnyDataProviderRepository(CovJMemoryRepository([wallet])),
            chainRepository: AnyDataProviderRepository(CovJMemoryRepository([chain])),
            operationQueue: OperationQueue()
        )
        let output = CovJWcProposalOutputSpy()
        interactor.setup(with: output)
        let delivered = await CovJWcProposalOutputSpy.wait { output.wallets.count == 1 && output.chains.count == 1 }
        XCTAssertTrue(delivered)
        XCTAssertEqual(try output.wallets[0].get().map(\.metaId), [wallet.metaId])
        XCTAssertEqual(try output.chains[0].get().map(\.chainId), [chain.chainId])

        try await interactor.submit(proposalDecision: .reject(proposal: CovJWcFixture.proposal()))
        try await interactor.submitDisconnect(topic: "wc-topic")
        XCTAssertEqual(service.proposalDecisions.count, 1)
        XCTAssertEqual(service.disconnected.all, ["wc-topic"])
    }

    func testInteractorReportsRepositoryFailures() {
        let wallets = CovJMemoryRepository<MetaAccountModel>()
        wallets.failure = CovJError("wallets")
        let chains = CovJMemoryRepository<ChainModel>()
        chains.failure = CovJError("chains")
        let interactor = WalletConnectProposalInteractor(
            walletConnect: CovJWcServiceStub(),
            walletRepository: AnyDataProviderRepository(wallets),
            chainRepository: AnyDataProviderRepository(chains),
            operationQueue: OperationQueue()
        )
        let output = CovJWcProposalOutputSpy()
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.wallets.count == 1 && output.chains.count == 1 })
        XCTAssertThrowsError(try output.wallets[0].get()) { XCTAssertEqual($0 as? CovJError, CovJError("wallets")) }
        XCTAssertThrowsError(try output.chains[0].get()) { XCTAssertEqual($0 as? CovJError, CovJError("chains")) }
    }

    func testRouterPresentsAllDoneAndNetworkSelection() throws {
        let router = WalletConnectProposalRouter()
        let host = try CovJHostedView()
        defer { host.close() }
        router.showAllDone(title: "All done", description: "Connected to Uniswap", view: host) {}
        let allDone = try XCTUnwrap(host.presented as? AllDoneViewController)
        XCTAssertEqual(allDone.modalPresentationStyle, .custom)

        let selectHost = try CovJHostedView()
        defer { selectHost.close() }
        let chain = CovJWcFixture.evmChain()
        router.showMultiSelect(canSelect: true, dataSource: [chain], selectedChains: [chain.chainId], moduleOutput: nil, view: selectHost)
        XCTAssertTrue(selectHost.presented is MultiSelectNetworksViewController)
        router.showMultiSelect(canSelect: false, dataSource: [], selectedChains: nil, moduleOutput: nil, view: nil)
        router.showAllDone(title: "", description: "", view: nil) {}
        XCTAssertTrue(selectHost.presented is MultiSelectNetworksViewController)
    }

    func testSupportedMethodsPassValidationWithoutAWarning() {
        let router = CovJWcProposalRouterSpy()
        let validating = WalletConnectProposalDataValidating(presentable: router)
        var approvals = 0
        let methods = WalletConnectMethod.allCases.map(\.rawValue)
        DataValidationRunner(validators: [
            validating.validate(requiredMethods: methods, view: nil, locale: CovJWcFixture.locale) { XCTFail("No rejection expected") },
            validating.validate(requiredMethods: [], view: nil, locale: CovJWcFixture.locale, onReject: nil)
        ]).runValidation { approvals += 1 }
        XCTAssertEqual(approvals, 1)
        XCTAssertTrue(router.warnings.isEmpty)
    }

    func testProposalLayoutTitlesAndWalletCellSelection() throws {
        let layout = WalletConnectProposalViewLayout(status: .proposal(CovJWcFixture.proposal()))
        let window = try CovJViewFixture.host(layout)
        defer { window.isHidden = true }
        layout.locale = CovJWcFixture.locale
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.connectDetails(preferredLanguages: languages))
        XCTAssertEqual(layout.mainActionButton.imageWithTitleView?.title, R.string.localizable.commonApprove(preferredLanguages: languages))
        XCTAssertEqual(layout.rejectButton.imageWithTitleView?.title, R.string.localizable.commonReject(preferredLanguages: languages))
        XCTAssertNotNil(layout.rejectButton.superview)
        layout.setExpiryDate(string: nil)
        XCTAssertFalse(layout.tableView.tableFooterView === layout.expiryDateView)

        let active = WalletConnectProposalViewLayout(status: .active(CovJWcFixture.session()))
        active.locale = CovJWcFixture.locale
        XCTAssertEqual(active.expiryDateView.titleLabel.text, R.string.localizable.commonExpiry(preferredLanguages: languages))
        XCTAssertEqual(active.mainActionButton.imageWithTitleView?.title, R.string.localizable.commonDisconnect(preferredLanguages: languages))

        let cell = WalletConnectProposalWalletsTableCell(style: .default, reuseIdentifier: nil)
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertNotNil(cell.view.iconImage)
        XCTAssertFalse(cell.view.isUserInteractionEnabled)
        cell.bind(viewModel: .init(metaId: "a", walletName: "Savings", isSelected: false))
        XCTAssertEqual(cell.view.title, "Savings")
        cell.bind(viewModel: WalletConnectProposalCellModel.WalletViewModel(metaId: "a", walletName: "Savings", isSelected: false).toggle())
        XCTAssertEqual(cell.view.title, "Savings")
    }
}

final class CovJWcProposalViewOutputSpy: WalletConnectProposalViewOutput {
    private(set) var loads = 0
    private(set) var disappearances = 0
    private(set) var selected: [IndexPath] = []

    func didLoad(view _: WalletConnectProposalViewInput) { loads += 1 }
    func viewDidDisappear() { disappearances += 1 }
    func backButtonDidTapped() {}
    func mainActionButtonDidTapped() {}
    func rejectButtonDidTapped() {}
    func didSelectRowAt(_ indexPath: IndexPath) { selected.append(indexPath) }
}

final class CovJWcProposalScreenTests: XCTestCase {
    func testAppIconLoadsIntoTheDetailsRowAndHiddenWindowKeepsTheSheetOpen() throws {
        let output = CovJWcProposalViewOutputSpy()
        let controller = WalletConnectProposalViewController(
            status: .active(CovJWcFixture.session()), output: output, localizationManager: try CovJWcFixture.localization()
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        XCTAssertEqual(output.loads, 1)
        let icon = CovJWcImageStub()
        let details = WalletConnectProposalCellModel.DetailsViewModel(title: "Uniswap", subtitle: "app.uniswap.invalid", icon: icon)
        controller.didReceive(viewModel: WalletConnectProposalViewModel(indexPath: nil, cells: [.dAppInfo(details)], expiryDate: nil))
        let table = controller.rootView.tableView
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? WalletConnectProposalDetailsTableCell)
        XCTAssertTrue(icon.loads.contains { $0 === cell.view.iconView })
        XCTAssertTrue(icon.lastPlaceholderIsImage)
        XCTAssertTrue(cell.dropTriangleImageView.isHidden)
        XCTAssertEqual(cell.view.title, "Uniswap")
        XCTAssertTrue(controller.rootView.mainActionButton.isEnabled, "An active session can always be disconnected")
        XCTAssertTrue(controller.rootView.tableView.tableFooterView !== controller.rootView.expiryDateView)

        window.isHidden = true
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.disappearances, 0, "Hidden with its window while the app is locked: still open")
        window.isHidden = false
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.disappearances, 1)
    }
}

final class CovJWcProposalOutputSpy: WalletConnectProposalInteractorOutput {
    private(set) var wallets: [Result<[MetaAccountModel], Error>] = []
    private(set) var chains: [Result<[ChainModel], Error>] = []

    func didReceive(walletsResult: Result<[MetaAccountModel], Error>) { wallets.append(walletsResult) }
    func didReceive(chainsResult: Result<[ChainModel], Error>) { chains.append(chainsResult) }

    /// Polls on the main actor so async tests can wait for main-actor deliveries.
    @MainActor
    static func wait(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
