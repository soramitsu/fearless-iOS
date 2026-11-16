import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SSFModels
import FearlessWalletConnect
@testable import fearless

final class CovJWcSessionViewSpy: UIViewController, WalletConnectSessionViewInput {
    private(set) var models: [WalletConnectSessionViewModel] = []
    private(set) var starts = 0
    private(set) var stops = 0

    func didReceive(viewModel: WalletConnectSessionViewModel) { models.append(viewModel) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJWcSessionInteractorStub: WalletConnectSessionInteractorInput {
    weak var output: WalletConnectSessionInteractorOutput?
    let signDecisions = CovJWcCalls<WalletConnectSignDecision>()
    let proposalDecisions = CovJWcCalls<WalletConnectProposalDecision>()
    var failure: Error?

    func setup(with output: WalletConnectSessionInteractorOutput) { self.output = output }

    func submit(proposalDecision: WalletConnectProposalDecision) async throws {
        proposalDecisions.append(proposalDecision)
        if let failure { throw failure }
    }

    func submit(signDecision: WalletConnectSignDecision) async throws {
        signDecisions.append(signDecision)
        if let failure { throw failure }
    }
}

final class CovJWcSessionRouterSpy: CovJSheetSpy, WalletConnectSessionRouterInput {
    private(set) var dismissals = 0
    private(set) var confirmations: [WalletConnectConfirmationInputData] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func showConfirmation(inputData: WalletConnectConfirmationInputData) { confirmations.append(inputData) }
}

final class CovJWcPreparerStub: WalletConnectRequestPreparing {
    let calls = CovJWcCalls<(topic: String, wallets: Int, chains: Int)>()
    let outcome: Result<WalletConnectSigningRequest, Error>

    init(outcome: Result<WalletConnectSigningRequest, Error>) {
        self.outcome = outcome
    }

    func prepare(request _: Request, session: Session, wallets: [MetaAccountModel], chains: [ChainModel]) async throws -> WalletConnectSigningRequest {
        calls.append((session.topic, wallets.count, chains.count))
        return try outcome.get()
    }
}

enum CovJWcSessionFixture {
    static func factory(session: Session?, verification: WalletConnectVerification) -> WalletConnectSessionViewModelFactoryImpl {
        WalletConnectSessionViewModelFactoryImpl(
            session: session,
            verification: verification,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            accountScoreFetcher: CovJWcStatisticsStub(),
            settings: InMemorySettingsManager()
        )
    }

    static func balance(for wallet: MetaAccountModel, hiddenFiat: Decimal = 0, dayChange: Decimal = -12) -> WalletBalanceInfo {
        var exclusions = PortfolioExclusions()
        exclusions.hiddenFiat = hiddenFiat
        return WalletBalanceInfo(
            totalFiatValue: 1234.5, enabledAssetFiatBalance: 1234.5,
            dayChangePercent: 0.05, dayChangeValue: dayChange,
            totalDayChangePercent: 0.05, totalDayChangeValue: dayChange,
            currency: wallet.selectedCurrency, prices: [], accountInfos: [:], exclusions: exclusions, filteredPart: nil
        )
    }

    static func rejection(_ decision: WalletConnectSignDecision?) -> (id: Int64, error: FearlessWalletConnect.JSONRPCError)? {
        guard let decision, case let .rejected(request, error) = decision else { return nil }
        return (request.id, error)
    }
}

final class CovJWcSessionPresenterTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    private func makePresenter(
        session: Session?,
        preparer: CovJWcPreparerStub,
        interactor: CovJWcSessionInteractorStub,
        router: CovJWcSessionRouterSpy,
        verification: WalletConnectVerification = .verified
    ) throws -> (WalletConnectSessionPresenter, Request) {
        let request = try CovJWcFixture.request()
        let presenter = WalletConnectSessionPresenter(
            request: request,
            session: session,
            verification: verification,
            viewModelFactory: CovJWcSessionFixture.factory(session: session, verification: verification),
            preparer: preparer,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: try CovJWcFixture.localization()
        )
        return (presenter, request)
    }

    func testPreparesOnceShowsTheRequestRefreshesBalanceAndOpensConfirmation() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let signing = try CovJWcFixture.signingRequest(wallet: wallet)
        let preparer = CovJWcPreparerStub(outcome: .success(signing))
        let interactor = CovJWcSessionInteractorStub()
        let router = CovJWcSessionRouterSpy()
        let (presenter, _) = try makePresenter(session: CovJWcFixture.session(), preparer: preparer, interactor: interactor, router: router)
        let view = CovJWcSessionViewSpy()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)

        presenter.didReceive(chainsResult: .success([CovJWcFixture.evmChain()]))
        presenter.didReceive(walletsResult: .failure(CovJError()))
        presenter.didReceive(chainsResult: .failure(CovJError()))
        presenter.didReceiveBalance(result: .failure(CovJError()))
        XCTAssertEqual(preparer.calls.count, 0, "Nothing is prepared before both wallets and chains arrive")

        presenter.didReceive(walletsResult: .success([wallet]))
        presenter.didReceive(walletsResult: .success([wallet]))
        XCTAssertTrue(CovJWait.until(timeout: 5) { view.models.count == 1 })
        XCTAssertEqual(preparer.calls.count, 1, "The request is decoded once")
        XCTAssertEqual(preparer.calls.all[0].topic, "wc-topic")
        XCTAssertEqual(preparer.calls.all[0].wallets, 1)
        XCTAssertEqual(preparer.calls.all[0].chains, 1)
        let first = view.models[0]
        XCTAssertEqual(first.dApp, "app.uniswap.invalid")
        XCTAssertEqual(first.verification, WalletConnectVerification.verified.title(for: CovJWcFixture.locale))
        XCTAssertEqual(first.messagePreview, "Sign in to Uniswap")
        XCTAssertEqual(first.walletViewModel.walletName, wallet.name)
        XCTAssertNil(first.walletViewModel.fiatBalance)

        presenter.didReceiveBalance(result: .success([wallet.metaId: CovJWcSessionFixture.balance(for: wallet)]))
        XCTAssertEqual(view.models.count, 2)
        XCTAssertNotNil(view.models[1].walletViewModel.fiatBalance)
        XCTAssertNotNil(view.models[1].walletViewModel.dayChange)
        XCTAssertEqual(preparer.calls.count, 1, "A balance update does not quote the request again")

        presenter.actionButtonDidTapped()
        XCTAssertEqual(view.starts, 1)
        XCTAssertEqual(view.stops, 1)
        let input = try XCTUnwrap(router.confirmations.first)
        XCTAssertEqual(input.session.topic, "wc-topic")
        XCTAssertEqual(input.verification, .verified)
        XCTAssertEqual(input.signingRequest.request.id, signing.request.id)
        XCTAssertEqual(input.signingRequest.wallet.metaId, wallet.metaId)

        presenter.closeButtonDidTapped()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertTrue(router.sheets.isEmpty)
        XCTAssertEqual(interactor.signDecisions.count, 0)
    }

    func testMissingSessionDeclinesWithTheAccountErrorAndRejectsTheRequest() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let preparer = CovJWcPreparerStub(outcome: .success(try CovJWcFixture.signingRequest(wallet: wallet)))
        let interactor = CovJWcSessionInteractorStub()
        let router = CovJWcSessionRouterSpy()
        let (presenter, request) = try makePresenter(session: nil, preparer: preparer, interactor: interactor, router: router)
        let view = CovJWcSessionViewSpy()
        presenter.didLoad(view: view)
        presenter.didReceive(chainsResult: .success([CovJWcFixture.evmChain()]))
        presenter.didReceive(walletsResult: .success([wallet]))

        XCTAssertEqual(preparer.calls.count, 0)
        XCTAssertEqual(view.stops, 1)
        let sheet = try XCTUnwrap(router.sheets.first)
        XCTAssertEqual(sheet.title, R.string.localizable.walletConnectRequestRejectedTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.walletConnectRequestErrorAccount(preferredLanguages: languages))
        XCTAssertNil(sheet.closeAction)
        XCTAssertTrue(sheet.actions.isEmpty)
        XCTAssertTrue(CovJWait.until(timeout: 5) { interactor.signDecisions.count == 1 })
        let rejection = try XCTUnwrap(CovJWcSessionFixture.rejection(interactor.signDecisions.all.first))
        XCTAssertEqual(rejection.id, request.id)
        XCTAssertEqual(rejection.error.code, 4100)

        sheet.dismissCompletion?()
        XCTAssertEqual(router.dismissals, 1)
        presenter.didReceive(walletsResult: .success([wallet]))
        XCTAssertEqual(router.sheets.count, 1, "A declined request is not handled again")
        presenter.actionButtonDidTapped()
        XCTAssertEqual(view.starts, 1)
        XCTAssertEqual(view.stops, 2)
        XCTAssertTrue(router.confirmations.isEmpty)
        XCTAssertTrue(view.models.isEmpty)
    }

    func testPreparationFailuresAreShownAndRejectedWithTheirCodes() throws {
        let cases: [(Error, String, String, Int)] = [
            (FearlessWalletConnect.JSONRPCError(code: -32602, message: "Bad params"), "-32602", "Bad params", -32602),
            (NSError(domain: "covj", code: 7, userInfo: [NSLocalizedDescriptionKey: "Broken node"]), "7", "Broken node", 7),
            (
                WalletConnectRequestError.feeUnavailable,
                R.string.localizable.walletConnectRequestRejectedTitle(preferredLanguages: languages),
                R.string.localizable.walletConnectRequestErrorFee(preferredLanguages: languages),
                -32603
            )
        ]
        for (error, title, message, code) in cases {
            let preparer = CovJWcPreparerStub(outcome: .failure(error))
            let interactor = CovJWcSessionInteractorStub()
            let router = CovJWcSessionRouterSpy()
            let (presenter, request) = try makePresenter(
                session: CovJWcFixture.session(), preparer: preparer, interactor: interactor, router: router, verification: .unverified
            )
            let view = CovJWcSessionViewSpy()
            presenter.didLoad(view: view)
            presenter.didReceive(walletsResult: .success([AccountGenerator.generateMetaAccount()]))
            presenter.didReceive(chainsResult: .success([CovJWcFixture.evmChain()]))
            XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 && interactor.signDecisions.count == 1 }, title)
            XCTAssertEqual(router.sheets.first?.title, title)
            XCTAssertEqual(router.sheets.first?.message, message)
            let rejection = try XCTUnwrap(CovJWcSessionFixture.rejection(interactor.signDecisions.all.first))
            XCTAssertEqual(rejection.id, request.id)
            XCTAssertEqual(rejection.error.code, code)
            XCTAssertEqual(view.stops, 1)
            XCTAssertTrue(view.models.isEmpty)
            presenter.didReceiveBalance(result: .success([:]))
            XCTAssertTrue(view.models.isEmpty, "A declined request shows nothing")
        }
    }

    func testDisappearingRejectsAsTheUserAndToleratesASubmitFailure() throws {
        let preparer = CovJWcPreparerStub(outcome: .failure(CovJError()))
        let interactor = CovJWcSessionInteractorStub()
        interactor.failure = CovJError("relay down")
        let router = CovJWcSessionRouterSpy()
        let (presenter, request) = try makePresenter(session: CovJWcFixture.session(), preparer: preparer, interactor: interactor, router: router)
        let view = CovJWcSessionViewSpy()
        var interactionDismissals = 0
        view.addOnInteractionDismiss { interactionDismissals += 1 }
        presenter.didLoad(view: view)
        presenter.applyLocalization()

        presenter.viewDidDisappear()
        XCTAssertEqual(interactionDismissals, 1)
        XCTAssertTrue(CovJWait.until(timeout: 5) { interactor.signDecisions.count == 1 })
        let rejection = try XCTUnwrap(CovJWcSessionFixture.rejection(interactor.signDecisions.all.first))
        XCTAssertEqual(rejection.id, request.id)
        XCTAssertEqual(rejection.error.code, 4001)
        XCTAssertEqual(rejection.error.message, "User rejected request")
        XCTAssertEqual(preparer.calls.count, 0)
        XCTAssertTrue(router.sheets.isEmpty)
    }
}

final class CovJWcSessionViewModelFactoryTests: XCTestCase {
    private let locale = CovJWcFixture.locale
    private var languages: [String]? { CovJWcFixture.languages }

    func testVerifiedSessionShowsTheClaimedSiteAndTheGeneralWarning() throws {
        let session = CovJWcFixture.session(url: "https://app.uniswap.invalid/swap")
        let wallet = AccountGenerator.generateMetaAccount()
        let model = CovJWcSessionFixture.factory(session: session, verification: .verified)
            .buildViewModel(signingRequest: try CovJWcFixture.signingRequest(wallet: wallet), balanceInfo: nil, locale: locale)
        XCTAssertEqual(model.dApp, "app.uniswap.invalid")
        XCTAssertEqual(model.verification, R.string.localizable.walletConnectVerifyValid(preferredLanguages: languages))
        XCTAssertTrue(CovJWcColor.same(model.verificationColor, R.color.colorGreen()))
        let label = R.string.localizable.commonWarningCapitalized(preferredLanguages: languages)
        let message = R.string.localizable.walletConnectSignWarningMessage(preferredLanguages: languages)
        let warning = try XCTUnwrap(model.warning)
        XCTAssertEqual(warning.string, "\(label) \(message)")
        XCTAssertEqual(warning.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, UIFont.h6Title)
        XCTAssertEqual(warning.attribute(.font, at: label.count, effectiveRange: nil) as? UIFont, UIFont.p2Paragraph)
        XCTAssertNotNil(warning.attribute(.foregroundColor, at: 0, effectiveRange: nil))
        XCTAssertEqual(model.walletViewModel.walletName, wallet.name)
        XCTAssertFalse(model.walletViewModel.isSelected)
        XCTAssertNil(model.walletViewModel.fiatBalance)
        XCTAssertNil(model.walletViewModel.dayChange)
        XCTAssertNil(model.walletViewModel.balanceCaption)
        XCTAssertEqual(model.walletViewModel.accountScoreViewModel?.address, wallet.ethereumAddress?.toHex(includePrefix: true))
        XCTAssertEqual(model.messagePreview, "Sign in to Uniswap")
    }

    func testVerifyFindingsChangeTheSiteColorAndWarning() throws {
        let signing = try CovJWcFixture.signingRequest()
        let mismatch = CovJWcSessionFixture.factory(session: CovJWcFixture.session(), verification: .mismatch(origin: "https://evil.invalid/x"))
            .buildViewModel(signingRequest: signing, balanceInfo: nil, locale: locale)
        XCTAssertEqual(mismatch.dApp, "evil.invalid")
        XCTAssertEqual(mismatch.verification, R.string.localizable.walletConnectVerifyInvalid(preferredLanguages: languages))
        XCTAssertTrue(CovJWcColor.same(mismatch.verificationColor, R.color.colorOrange()))
        XCTAssertTrue(mismatch.warning?.string.hasSuffix(R.string.localizable.walletConnectVerifyInvalidWarning(preferredLanguages: languages)) == true)

        let unverified = CovJWcSessionFixture.factory(session: nil, verification: .unverified)
            .buildViewModel(signingRequest: signing, balanceInfo: nil, locale: locale)
        XCTAssertNil(unverified.dApp)
        XCTAssertTrue(unverified.warning?.string.hasSuffix(R.string.localizable.walletConnectVerifyUnknownWarning(preferredLanguages: languages)) == true)

        let scam = CovJWcSessionFixture.factory(session: CovJWcFixture.session(), verification: .scam)
            .buildViewModel(signingRequest: signing, balanceInfo: nil, locale: locale)
        XCTAssertEqual(scam.verification, R.string.localizable.walletConnectVerifyScam(preferredLanguages: languages))
        XCTAssertTrue(CovJWcColor.same(scam.verificationColor, R.color.colorRed()))
        XCTAssertTrue(scam.warning?.string.hasSuffix(R.string.localizable.walletConnectSignWarningMessage(preferredLanguages: languages)) == true)
    }

    func testMessagePreviewFollowsTheRequestContent() throws {
        let factory = CovJWcSessionFixture.factory(session: CovJWcFixture.session(), verification: .verified)
        func preview(_ content: WalletConnectSigningRequest.Content) throws -> String {
            factory.buildViewModel(signingRequest: try CovJWcFixture.signingRequest(content: content), balanceInfo: nil, locale: locale).messagePreview
        }
        XCTAssertEqual(try preview(.polkadotMessage(WalletConnectMessage(bytes: Data([0x00, 0xFF])))), "0x00ff")
        XCTAssertEqual(try preview(.polkadotMessage(WalletConnectMessage(bytes: Data("line one\nline two".utf8)))), "line one\nline two")
        let permit = WalletConnectTypedData(
            signingInput: Data([0x19, 0x01]), primaryType: "PermitSingle", domainName: "Permit2", verifyingContract: nil, allowance: nil
        )
        XCTAssertEqual(try preview(.ethereumTypedData(permit)), "Permit2 · PermitSingle")
        let unnamed = WalletConnectTypedData(signingInput: Data(), primaryType: "Mail", domainName: "", verifyingContract: nil, allowance: nil)
        XCTAssertEqual(try preview(.ethereumTypedData(unnamed)), "Mail")
        let anonymous = WalletConnectTypedData(signingInput: Data(), primaryType: "Order", domainName: nil, verifyingContract: nil, allowance: nil)
        XCTAssertEqual(try preview(.ethereumTypedData(anonymous)), "Order")
        let quote = WalletConnectEthereumTransactionQuote(
            chainId: 1, from: Data(repeating: 1, count: 20), to: Data(repeating: 2, count: 20), value: 5, data: Data(),
            nonce: 0, gasLimit: 21000, fee: .legacy(gasPrice: 1), tokenCall: nil
        )
        XCTAssertEqual(try preview(.ethereumTransaction(quote)), "transaction preview")
    }

    func testWalletBalanceFillsFiatDayChangeAndHiddenCaption() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let factory = CovJWcSessionFixture.factory(session: CovJWcFixture.session(), verification: .verified)
        let signing = try CovJWcFixture.signingRequest(wallet: wallet)
        let info = CovJWcSessionFixture.balance(for: wallet, hiddenFiat: 5, dayChange: -12)
        let model = factory.buildViewModel(signingRequest: signing, balanceInfo: [wallet.metaId: info], locale: locale)
        let formatter = AssetBalanceFormatterFactory()
            .createTokenFormatter(for: AssetBalanceDisplayInfo.forCurrency(wallet.selectedCurrency), usageCase: .fiat)
            .value(for: locale)
        XCTAssertEqual(model.walletViewModel.fiatBalance, formatter.stringFromDecimal(1234.5))
        let percent = info.totalDayChangePercent.percentString(locale: locale) ?? ""
        XCTAssertEqual(model.walletViewModel.dayChange?.string, "\(percent) (\(formatter.stringFromDecimal(12) ?? ""))")
        XCTAssertNotNil(model.walletViewModel.balanceCaption)

        let other = factory.buildViewModel(signingRequest: signing, balanceInfo: ["another-wallet": info], locale: locale)
        XCTAssertNil(other.walletViewModel.fiatBalance)
        let flat = factory.buildViewModel(
            signingRequest: signing,
            balanceInfo: [wallet.metaId: CovJWcSessionFixture.balance(for: wallet, dayChange: 0)],
            locale: locale
        )
        XCTAssertNil(flat.walletViewModel.balanceCaption)
        XCTAssertEqual(flat.walletViewModel.dayChange?.string, "\(percent) (\(formatter.stringFromDecimal(0) ?? ""))")
    }
}
