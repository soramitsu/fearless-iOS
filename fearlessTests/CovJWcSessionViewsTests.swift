import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
import FearlessWalletConnect
@testable import fearless

final class CovJWcSessionInteractorOutputSpy: WalletConnectSessionInteractorOutput {
    private(set) var balances: [WalletBalancesResult] = []
    private(set) var chains: [Result<[ChainModel], Error>] = []
    private(set) var wallets: [Result<[MetaAccountModel], Error>] = []

    func didReceiveBalance(result: WalletBalancesResult) { balances.append(result) }
    func didReceive(chainsResult: Result<[ChainModel], Error>) { chains.append(chainsResult) }
    func didReceive(walletsResult: Result<[MetaAccountModel], Error>) { wallets.append(walletsResult) }
}

final class CovJWcSessionOutputSpy: WalletConnectSessionViewOutput {
    private(set) var loads = 0
    private(set) var disappearances = 0
    private(set) var closes = 0
    private(set) var actions = 0

    func didLoad(view _: WalletConnectSessionViewInput) { loads += 1 }
    func viewDidDisappear() { disappearances += 1 }
    func closeButtonDidTapped() { closes += 1 }
    func actionButtonDidTapped() { actions += 1 }
}

final class CovJWcSessionInteractorTests: XCTestCase {
    private func makeInteractor(
        service: CovJWcServiceStub,
        adapter: CovJWcBalanceAdapterStub,
        wallets: CovJMemoryRepository<MetaAccountModel>,
        chains: CovJMemoryRepository<ChainModel>
    ) -> WalletConnectSessionInteractor {
        WalletConnectSessionInteractor(
            walletConnect: service,
            walletBalanceSubscriptionAdapter: adapter,
            walletRepository: AnyDataProviderRepository(wallets),
            chainRepository: AnyDataProviderRepository(chains),
            operationQueue: OperationQueue()
        )
    }

    func testSetupSubscribesBalancesAndDeliversWalletsAndChains() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJWcFixture.evmChain()
        let adapter = CovJWcBalanceAdapterStub()
        let interactor = makeInteractor(
            service: CovJWcServiceStub(), adapter: adapter,
            wallets: CovJMemoryRepository([wallet]), chains: CovJMemoryRepository([chain])
        )
        let output = CovJWcSessionInteractorOutputSpy()
        interactor.setup(with: output)

        XCTAssertEqual(adapter.walletsListeners.count, 1)
        let listener = try XCTUnwrap(adapter.walletsListeners.first)
        XCTAssertTrue(listener === interactor)
        guard case .wallets = listener.type else { return XCTFail("The request sheet listens to every wallet") }
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.chains.count == 1 && output.wallets.count == 1 })
        XCTAssertEqual(try output.chains[0].get().map(\.chainId), [chain.chainId])
        XCTAssertEqual(try output.wallets[0].get().map(\.metaId), [wallet.metaId])

        listener.handle(result: .success([:]))
        listener.handle(result: .failure(CovJError()))
        XCTAssertEqual(output.balances.count, 2)
        XCTAssertEqual(try output.balances[0].get().count, 0)
    }

    func testRepositoryFailuresAreDelivered() {
        let walletRepository = CovJMemoryRepository<MetaAccountModel>()
        walletRepository.failure = CovJError("wallets")
        let chainRepository = CovJMemoryRepository<ChainModel>()
        chainRepository.failure = CovJError("chains")
        let interactor = makeInteractor(
            service: CovJWcServiceStub(), adapter: CovJWcBalanceAdapterStub(), wallets: walletRepository, chains: chainRepository
        )
        let output = CovJWcSessionInteractorOutputSpy()
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.chains.count == 1 && output.wallets.count == 1 })
        XCTAssertThrowsError(try output.chains[0].get()) { XCTAssertEqual($0 as? CovJError, CovJError("chains")) }
        XCTAssertThrowsError(try output.wallets[0].get()) { XCTAssertEqual($0 as? CovJError, CovJError("wallets")) }
    }

    func testDecisionsGoToTheService() async throws {
        let service = CovJWcServiceStub()
        let interactor = makeInteractor(
            service: service, adapter: CovJWcBalanceAdapterStub(), wallets: CovJMemoryRepository(), chains: CovJMemoryRepository()
        )
        let request = try CovJWcFixture.request()
        try await interactor.submit(signDecision: .rejected(request: request, error: .userRejected))
        try await interactor.submit(proposalDecision: .reject(proposal: CovJWcFixture.proposal()))
        XCTAssertEqual(service.signDecisions.count, 1)
        XCTAssertEqual(service.proposalDecisions.count, 1)
        guard case let .rejected(sent, error) = try XCTUnwrap(service.signDecisions.all.first) else {
            return XCTFail("Expected a rejection")
        }
        XCTAssertEqual(sent.id, request.id)
        XCTAssertEqual(error.code, 4001)

        service.failure = CovJError("relay")
        do {
            try await interactor.submit(signDecision: .rejected(request: request, error: .userRejected))
            XCTFail("A relay failure reaches the caller")
        } catch {
            XCTAssertEqual(error as? CovJError, CovJError("relay"))
        }
    }
}

final class CovJWcSessionViewsTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    func testSheetLocalizesShowsTheRequestAndForwardsActions() throws {
        let output = CovJWcSessionOutputSpy()
        let controller = WalletConnectSessionViewController(output: output, localizationManager: try CovJWcFixture.localization())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = controller.rootView
        let table = layout.tableView
        XCTAssertEqual(output.loads, 1)
        var texts = CovJViewFixture.descendants(UILabel.self, in: layout).compactMap(\.text)
        XCTAssertTrue(texts.contains(R.string.localizable.signThisMessage(preferredLanguages: languages)))
        XCTAssertTrue(texts.contains(R.string.localizable.commonMessage(preferredLanguages: languages)))
        XCTAssertEqual(layout.actionButton.imageWithTitleView?.title, R.string.localizable.commonPreview(preferredLanguages: languages))
        XCTAssertEqual(controller.numberOfSections(in: table), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: indexPath) as? WalletsManagmentTableCell)
        controller.tableView(table, willDisplay: cell, forRowAt: indexPath)
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: indexPath)

        let wallet = AccountGenerator.generateMetaAccount()
        let model = CovJWcSessionFixture.factory(session: CovJWcFixture.session(), verification: .mismatch(origin: "https://evil.invalid"))
            .buildViewModel(
                signingRequest: try CovJWcFixture.signingRequest(content: CovJWcFixture.message("Approve login"), wallet: wallet),
                balanceInfo: nil,
                locale: CovJWcFixture.locale
            )
        controller.didReceive(viewModel: model)
        layout.layoutIfNeeded()
        texts = CovJViewFixture.descendants(UILabel.self, in: layout).compactMap(\.text)
        XCTAssertTrue(texts.contains("evil.invalid"))
        XCTAssertTrue(texts.contains(R.string.localizable.walletConnectVerifyInvalid(preferredLanguages: languages)))
        XCTAssertTrue(texts.contains("Approve login"))
        let warningLabel = CovJViewFixture.descendants(UILabel.self, in: layout).first { $0.attributedText?.string == model.warning?.string }
        XCTAssertNotNil(warningLabel)
        let verificationLabel = CovJViewFixture.descendants(UILabel.self, in: layout).first { $0.text == model.verification }
        XCTAssertTrue(CovJWcColor.same(verificationLabel?.textColor, R.color.colorOrange()))

        let walletCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: indexPath) as? WalletsManagmentTableCell)
        controller.tableView(table, willDisplay: walletCell, forRowAt: indexPath)
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: walletCell).compactMap(\.text).contains(wallet.name))

        layout.closeButton.sendActions(for: .touchUpInside)
        layout.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.closes, 1)
        XCTAssertEqual(output.actions, 1)

        controller.applyLocalization()
        XCTAssertEqual(layout.locale.identifier, "en")
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.disappearances, 1, "Closing the visible sheet answers the request")
        window.isHidden = true
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.disappearances, 1, "A sheet hidden with its window stays open")
    }

    func testRouterHandsTheConfirmationInputToItsClosure() throws {
        var received: [WalletConnectConfirmationInputData] = []
        let router = WalletConnectSessionRouter { received.append($0) }
        let input = CovJWcFixture.inputData(try CovJWcFixture.signingRequest(), verification: .unverified)
        router.showConfirmation(inputData: input)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.verification, .unverified)
        XCTAssertEqual(received.first?.session.topic, "wc-topic")

        router.onGoToConfirmation = nil
        router.showConfirmation(inputData: input)
        XCTAssertEqual(received.count, 1)
        XCTAssertNil(WalletConnectSessionRouter(onGoToConfirmation: nil).onGoToConfirmation)
    }
}
