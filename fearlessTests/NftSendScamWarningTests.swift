import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import XCTest
@testable import fearless

/// The NFT send screen has a scam warning and passes scam info on to the confirmation, but nothing ever looked the
/// recipient up: `NftSendInteractor.fetchScamInfo` had no caller, so a known scam address was never flagged. It now
/// asks on every recipient change, the way token Send does.
final class NftSendScamWarningTests: XCTestCase {
    func testEveryRecipientChangeLooksUpTheRecipient() {
        let view = CovHNftSendViewSpy()
        let interactor = CovHNftSendInteractorSpy()
        let router = CovHNftSendRouterSpy()
        let chain = CovHNftFixtures.chain()
        let presenter = Self.presenter(interactor: interactor, router: router, view: view, chain: chain)

        presenter.searchTextDidChanged("0xtyped")
        presenter.didSelect(address: "0xcontact")
        presenter.searchTextDidChanged("")

        XCTAssertEqual(interactor.scamLookups, ["0xtyped", "0xcontact"], "an empty field is not looked up")
    }

    func testAScamRecipientIsFlaggedAndCarriedToTheConfirmation() throws {
        let chain = CovHNftFixtures.chain()
        let scam = ScamInfo(name: "Phisher", address: "0xscam", type: .scam, subtype: "Phishing")
        let fetcher = NftSendScamFetcherStub(answers: ["0xscam": scam])
        let context = Self.connected(chain: chain, fetcher: fetcher)

        context.presenter.searchTextDidChanged("0xscam")
        CovHNftWait.until { context.view.scams.contains { $0 != nil } }

        XCTAssertEqual(fetcher.addresses, ["0xscam"])
        XCTAssertEqual(context.view.scams.compactMap { $0 }, [scam], "the warning is shown")

        try Self.continueToConfirmation(context, chain: chain)
        XCTAssertEqual(context.router.confirms.map(\.0), ["0xscam"])
        XCTAssertEqual(context.router.confirms.first?.1, scam, "the confirmation gets the warning too")
    }

    func testAnotherRecipientClearsTheWarningAndALateAnswerForTheOldOneIsDropped() throws {
        let chain = CovHNftFixtures.chain()
        let scam = ScamInfo(name: "Phisher", address: "0xscam", type: .scam, subtype: "Phishing")
        let late = ScamInfo(name: "Late", address: "0xslow", type: .theft, subtype: "")
        let fetcher = NftSendScamFetcherStub(answers: ["0xscam": scam, "0xslow": late], slowAddresses: ["0xslow"])
        let context = Self.connected(chain: chain, fetcher: fetcher)

        context.presenter.searchTextDidChanged("0xscam")
        CovHNftWait.until { context.view.scams.last == scam }
        XCTAssertEqual(context.view.scams.last, scam)

        context.presenter.searchTextDidChanged("0xslow")
        context.presenter.searchTextDidChanged("0xclean")
        CovHNftWait.until { fetcher.answered.count == 3 }
        CovHNftWait.spin(0.3)

        XCTAssertEqual(fetcher.addresses, ["0xscam", "0xslow", "0xclean"])
        XCTAssertEqual(context.view.scams.last, .some(nil), "the old recipient's warning is gone")
        XCTAssertFalse(context.view.scams.contains(late), "an answer for an earlier recipient is not shown")

        try Self.continueToConfirmation(context, chain: chain)
        XCTAssertEqual(context.router.confirms.map(\.0), ["0xclean"])
        XCTAssertEqual(context.router.confirms.first?.1, .some(nil))
    }

    // MARK: - Helpers

    private struct Context {
        let view: CovHNftSendViewSpy
        let router: CovHNftSendRouterSpy
        let presenter: NftSendPresenter
        let interactor: NftSendInteractor
    }

    private static func presenter(
        interactor: NftSendInteractorInput,
        router: CovHNftSendRouterSpy,
        view: CovHNftSendViewSpy,
        chain: ChainModel
    ) -> NftSendPresenter {
        let validating = SendDataValidatingFactory(presentable: router)
        let presenter = NftSendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            nft: CovHNftFixtures.nft(chain: chain),
            wallet: CovHNftFixtures.wallet(),
            logger: Logger.shared,
            viewModelFactory: CovHNftSendViewModelFactoryStub(),
            dataValidatingFactory: validating
        )
        validating.view = view
        presenter.didLoad(view: view)
        return presenter
    }

    /// The screen's presenter on a real interactor with the given scam lookup.
    private static func connected(chain: ChainModel, fetcher: ScamInfoFetching) -> Context {
        let wallet = CovHNftFixtures.wallet()
        let interactor = NftSendInteractor(
            transferService: CovHNftTransferStub(),
            operationManager: OperationManagerFacade.sharedManager,
            scamInfoFetching: fetcher,
            addressChainDefiner: AddressChainDefiner(
                operationManager: OperationManagerFacade.sharedManager,
                chainModelRepository: AnyDataProviderRepository(CovFRepository<ChainModel>()),
                wallet: wallet
            ),
            accountInfoSubscriptionAdapter: CovHNftAccountInfoAdapterSpy(),
            chain: chain,
            wallet: wallet
        )
        let view = CovHNftSendViewSpy()
        let router = CovHNftSendRouterSpy()
        let presenter = Self.presenter(interactor: interactor, router: router, view: view, chain: chain)
        return Context(view: view, router: router, presenter: presenter, interactor: interactor)
    }

    private static func continueToConfirmation(_ context: Context, chain: ChainModel) throws {
        let utility = try XCTUnwrap(chain.utilityChainAssets().first)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1))))
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(5_000_000_000_000))), for: utility)
        context.presenter.didTapContinueButton()
    }
}

/// Answers scam lookups from a table; addresses in `slowAddresses` answer after half a second.
private final class NftSendScamFetcherStub: ScamInfoFetching {
    private let answers: [String: ScamInfo]
    private let slowAddresses: Set<String>
    private let lock = NSLock()
    private var storedAddresses: [String] = []
    private var storedAnswered: [String] = []

    var addresses: [String] { lock.lock(); defer { lock.unlock() }; return storedAddresses }
    var answered: [String] { lock.lock(); defer { lock.unlock() }; return storedAnswered }

    init(answers: [String: ScamInfo], slowAddresses: Set<String> = []) {
        self.answers = answers
        self.slowAddresses = slowAddresses
    }

    func fetch(address: String, chain _: ChainModel) async throws -> ScamInfo? {
        lock.lock()
        storedAddresses.append(address)
        lock.unlock()
        if slowAddresses.contains(address) {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        lock.lock()
        storedAnswered.append(address)
        lock.unlock()
        return answers[address]
    }
}
