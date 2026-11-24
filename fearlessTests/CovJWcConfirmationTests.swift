import XCTest
import UIKit
import SoraFoundation
import SSFModels
import SSFUtils
import FearlessWalletConnect
@testable import fearless

final class CovJWcConfirmationViewSpy: UIViewController, WalletConnectConfirmationViewInput {
    private(set) var models: [WalletConnectConfirmationViewModel] = []
    private(set) var starts = 0
    private(set) var stops = 0

    func didReceive(viewModel: WalletConnectConfirmationViewModel) { models.append(viewModel) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJWcConfirmationInteractorStub: WalletConnectConfirmationInteractorInput {
    weak var output: WalletConnectConfirmationInteractorOutput?
    let approvals = CovJWcCalls<Int>()
    let rejections = CovJWcCalls<Int>()
    private let lock = NSLock()
    private var outcomes: [Result<String?, Error>] = []

    func enqueue(_ outcome: Result<String?, Error>) {
        lock.lock()
        outcomes.append(outcome)
        lock.unlock()
    }

    func setup(with output: WalletConnectConfirmationInteractorOutput) { self.output = output }

    func reject() async throws { rejections.append(1) }

    func approve() async throws -> String? {
        approvals.append(1)
        return try nextOutcome().get()
    }

    private func nextOutcome() -> Result<String?, Error> {
        lock.lock()
        defer { lock.unlock() }
        return outcomes.isEmpty ? .success(nil) : outcomes.removeFirst()
    }
}

final class CovJWcConfirmationRouterSpy: CovJSheetSpy, WalletConnectConfirmationRouterInput {
    private(set) var dismissals = 0
    private(set) var allDone: [(chainId: String, hash: String?, closure: () -> Void)] = []
    private(set) var rawData: [JSON] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func showAllDone(chain: ChainModel, hashString: String?, view _: ControllerBackedProtocol?, closure: @escaping () -> Void) {
        allDone.append((chain.chainId, hashString, closure))
    }

    func showRawData(json: JSON, from _: ControllerBackedProtocol?) { rawData.append(json) }
}

final class CovJWcConfirmationFactoryStub: WalletConnectConfirmationViewModelFactory {
    private(set) var locales: [Locale] = []

    func buildViewModel(locale: Locale) -> WalletConnectConfirmationViewModel {
        locales.append(locale)
        return CovJWcConfirmationModels.model(method: "personal_sign #\(locales.count)")
    }
}

final class CovJWcConfirmationOutputSpy: WalletConnectConfirmationViewOutput {
    private(set) var loads = 0
    private(set) var backs = 0
    private(set) var raws = 0
    private(set) var confirms = 0

    func didLoad(view _: WalletConnectConfirmationViewInput) { loads += 1 }
    func backButtonDidTapped() { backs += 1 }
    func rawDataDidTapped() { raws += 1 }
    func confirmDidTapped() { confirms += 1 }
}

enum CovJWcConfirmationModels {
    typealias Row = WalletConnectConfirmationViewModel.Row

    static func model(method: String = "personal_sign", rows: [Row] = defaultRows) -> WalletConnectConfirmationViewModel {
        WalletConnectConfirmationViewModel(
            symbolViewModel: SymbolViewModel(symbolViewModel: nil, shadowColor: nil),
            method: method,
            rows: rows,
            rawData: NSAttributedString(string: "{\"raw\":true}")
        )
    }

    static let defaultRows: [Row] = [
        Row(kind: .network, title: "Network", value: "Ethereum"),
        Row(kind: .message, title: "Message", value: "Sign in to Uniswap\nwith nonce 7"),
        Row(kind: .warning, title: "Warning", value: "Unverified site")
    ]
}

final class CovJWcSignerStub: WalletConnectSigner {
    let signed = CovJWcCalls<String>()

    func sign(request: WalletConnectSigningRequest) async throws -> AnyCodable {
        signed.append(request.method.rawValue)
        return AnyCodable("0xsigned")
    }
}

final class CovJWcAuthorizerStub: WalletConnectSigningAuthorizing {
    var answer = true
    let asks = CovJWcCalls<Int>()

    func authorize() async -> Bool {
        asks.append(1)
        return answer
    }
}

final class CovJWcConfirmationInteractorOutputStub: WalletConnectConfirmationInteractorOutput {}

final class CovJWcConfirmationPresenterTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    private func makePresenter(
        interactor: CovJWcConfirmationInteractorStub,
        router: CovJWcConfirmationRouterSpy,
        factory: CovJWcConfirmationFactoryStub = CovJWcConfirmationFactoryStub()
    ) throws -> WalletConnectConfirmationPresenter {
        WalletConnectConfirmationPresenter(
            inputData: CovJWcFixture.inputData(try CovJWcFixture.signingRequest()),
            viewModelFactory: factory,
            interactor: interactor,
            router: router,
            localizationManager: try CovJWcFixture.localization()
        )
    }

    func testDidLoadBindsInteractorBuildsModelAndRefreshesOnlyLoadedViews() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        let router = CovJWcConfirmationRouterSpy()
        let factory = CovJWcConfirmationFactoryStub()
        let presenter = try makePresenter(interactor: interactor, router: router, factory: factory)
        let view = CovJWcConfirmationViewSpy()
        presenter.applyLocalization()
        XCTAssertTrue(factory.locales.isEmpty, "Nothing is built before the view loads")

        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.models.map(\.method), ["personal_sign #1"])
        XCTAssertEqual(factory.locales.map(\.identifier), ["en"])

        presenter.applyLocalization()
        XCTAssertEqual(view.models.count, 1, "A view that is not set up is not refreshed")
        view.loadViewIfNeeded()
        presenter.applyLocalization()
        XCTAssertEqual(view.models.map(\.method), ["personal_sign #1", "personal_sign #2"])

        presenter.backButtonDidTapped()
        presenter.rawDataDidTapped()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(router.rawData.count, 1)
        XCTAssertFalse(presenter.isSigning)
        XCTAssertTrue(router.sheets.isEmpty)
    }

    func testConfirmSignsOnceShowsAllDoneAndClosesTheFlow() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        interactor.enqueue(.success("0xfeed"))
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcConfirmationViewSpy()
        var interactionDismissals = 0
        view.addOnInteractionDismiss { interactionDismissals += 1 }
        presenter.didLoad(view: view)

        presenter.confirmDidTapped()
        XCTAssertTrue(presenter.isSigning)
        presenter.confirmDidTapped()
        XCTAssertEqual(view.starts, 1, "A second tap while signing is ignored")

        XCTAssertTrue(CovJWait.until(timeout: 5) { router.allDone.count == 1 })
        XCTAssertEqual(interactor.approvals.count, 1)
        XCTAssertFalse(presenter.isSigning)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(router.allDone[0].chainId, "1")
        XCTAssertEqual(router.allDone[0].hash, "0xfeed")
        XCTAssertEqual(interactor.rejections.count, 0)

        router.allDone[0].closure()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(interactionDismissals, 1)
    }

    func testPausedSigningRejectsAndShowsTheNoticeThatEndsTheFlow() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        interactor.enqueue(.failure(WalletConnectSigningError.paused))
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcConfirmationViewSpy()
        var interactionDismissals = 0
        view.addOnInteractionDismiss { interactionDismissals += 1 }
        presenter.didLoad(view: view)

        presenter.confirmDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        XCTAssertEqual(interactor.rejections.count, 1, "The app hears that the request was declined")
        XCTAssertFalse(presenter.isSigning)
        XCTAssertEqual(view.stops, 1)
        let sheet = router.sheets[0]
        XCTAssertEqual(sheet.title, R.string.localizable.walletConnectSigningPausedTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.walletConnectSigningPausedMessage(preferredLanguages: languages))
        XCTAssertNil(sheet.closeAction)
        XCTAssertNotNil(sheet.icon)
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.commonClose(preferredLanguages: languages)])
        XCTAssertTrue(sheet.actions[0].handlerAfterDismissal)
        XCTAssertTrue(router.allDone.isEmpty)

        sheet.actions[0].handler?()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(interactionDismissals, 1)
    }

    func testEndedRequestShowsItsNoticeWithoutRejecting() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        interactor.enqueue(.failure(WalletConnectSigningError.requestEnded))
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcConfirmationViewSpy()
        var interactionDismissals = 0
        view.addOnInteractionDismiss { interactionDismissals += 1 }
        presenter.didLoad(view: view)

        presenter.confirmDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        XCTAssertEqual(interactor.rejections.count, 0)
        XCTAssertEqual(view.stops, 1)
        let sheet = router.sheets[0]
        XCTAssertEqual(sheet.title, R.string.localizable.walletConnectRequestEndedTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.walletConnectRequestEndedMessage(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.count, 1)
        sheet.actions[0].handler?()
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(interactionDismissals, 1)
    }

    func testCancelledPinKeepsTheRequestOpenForAnotherTry() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        interactor.enqueue(.failure(WalletConnectSigningError.notAuthorized))
        interactor.enqueue(.success(nil))
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcConfirmationViewSpy()
        presenter.didLoad(view: view)

        presenter.confirmDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { view.stops == 1 })
        XCTAssertFalse(presenter.isSigning)
        XCTAssertTrue(router.sheets.isEmpty)
        XCTAssertTrue(router.allDone.isEmpty)
        XCTAssertEqual(router.dismissals, 0)

        presenter.confirmDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.allDone.count == 1 })
        XCTAssertEqual(interactor.approvals.count, 2)
        XCTAssertNil(router.allDone[0].hash)
        XCTAssertEqual(view.starts, 2)
        XCTAssertEqual(view.stops, 2)
    }

    func testOtherSigningFailureIsShownAsAnError() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        let failure = CovJError("signer offline")
        interactor.enqueue(.failure(failure))
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        let view = CovJWcConfirmationViewSpy()
        presenter.didLoad(view: view)

        presenter.confirmDidTapped()
        XCTAssertTrue(CovJWait.until(timeout: 5) { router.sheets.count == 1 })
        let sheet = router.sheets[0]
        XCTAssertEqual(sheet.title, "")
        XCTAssertEqual(sheet.message, "\(failure)")
        XCTAssertEqual(sheet.closeAction, R.string.localizable.commonCancel(preferredLanguages: languages))
        XCTAssertTrue(sheet.actions.isEmpty)
        XCTAssertFalse(presenter.isSigning)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(interactor.rejections.count, 0)
    }

    func testOutcomesWithoutAViewPresentNothing() throws {
        let interactor = CovJWcConfirmationInteractorStub()
        let router = CovJWcConfirmationRouterSpy()
        let presenter = try makePresenter(interactor: interactor, router: router)
        presenter.showRequestEnded()
        let outcomes: [Error] = [
            WalletConnectSigningError.paused,
            WalletConnectSigningError.requestEnded,
            WalletConnectSigningError.unavailable
        ]
        for (index, outcome) in outcomes.enumerated() {
            interactor.enqueue(.failure(outcome))
            presenter.confirmDidTapped()
            XCTAssertTrue(CovJWait.until(timeout: 5) { !presenter.isSigning && interactor.approvals.count == index + 1 })
        }
        XCTAssertEqual(interactor.rejections.count, 1)
        XCTAssertTrue(router.sheets.isEmpty)
        XCTAssertTrue(router.allDone.isEmpty)
    }
}

final class CovJWcConfirmationViewsTests: XCTestCase {
    private var languages: [String]? { CovJWcFixture.languages }

    func testControllerLocalizesBindsRowsAndForwardsActions() throws {
        let output = CovJWcConfirmationOutputSpy()
        let controller = WalletConnectConfirmationViewController(output: output, localizationManager: try CovJWcFixture.localization())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = controller.rootView
        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.commonPreview(preferredLanguages: languages))
        XCTAssertEqual(layout.rawDataView.titleLabel.text, R.string.localizable.commonTransactionRawData(preferredLanguages: languages))
        XCTAssertEqual(layout.confirmButton.imageWithTitleView?.title, R.string.localizable.commonSign(preferredLanguages: languages))

        controller.didReceive(viewModel: CovJWcConfirmationModels.model())
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.methodNameLabel.text, "personal_sign")
        XCTAssertEqual(layout.rowViews.map { $0.titleLabel.text }, ["Network", "Message", "Warning"])
        XCTAssertEqual(layout.rowViews.map { $0.valueLabel.text }, ["Ethereum", "Sign in to Uniswap\nwith nonce 7", "Unverified site"])
        XCTAssertEqual(layout.rowViews[0].valueLabel.numberOfLines, 1)
        XCTAssertEqual(layout.rowViews[0].valueLabel.lineBreakMode, .byTruncatingMiddle)
        XCTAssertEqual(layout.rowViews[1].valueLabel.numberOfLines, 0)
        XCTAssertEqual(layout.rowViews[1].valueLabel.lineBreakMode, .byWordWrapping)
        XCTAssertTrue(CovJWcColor.same(layout.rowViews[2].titleLabel.textColor, R.color.colorOrange()))
        XCTAssertTrue(CovJWcColor.same(layout.rowViews[2].valueLabel.textColor, R.color.colorOrange()))
        XCTAssertTrue(CovJWcColor.same(layout.rowViews[0].valueLabel.textColor, R.color.colorWhite()))
        XCTAssertTrue(CovJWcColor.same(layout.rowViews[0].titleLabel.textColor, R.color.colorStrokeGray()))
        XCTAssertEqual(layout.infoViewsStackView.arrangedSubviews.count, 4)
        XCTAssertTrue(layout.infoViewsStackView.arrangedSubviews.last === layout.rawDataView)
        XCTAssertEqual(layout.rawDataView.valueLabel.attributedText?.string, "{\"raw\":true}")

        let single = [CovJWcConfirmationModels.Row(kind: .fee, title: "Fee", value: "0.1 ETH")]
        controller.didReceive(viewModel: CovJWcConfirmationModels.model(method: "eth_sendTransaction", rows: single))
        XCTAssertEqual(layout.methodNameLabel.text, "eth_sendTransaction")
        XCTAssertEqual(layout.rowViews.count, 1)
        XCTAssertEqual(layout.infoViewsStackView.arrangedSubviews.count, 2, "Rows of the earlier request are removed")
        XCTAssertEqual(layout.rowViews[0].titleLabel.text, "Fee")

        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        layout.confirmButton.sendActions(for: .touchUpInside)
        layout.perform(NSSelectorFromString("handleRawDataTapped"))
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.confirms, 1)
        XCTAssertEqual(output.raws, 1)

        controller.applyLocalization()
        XCTAssertEqual(layout.locale.identifier, "en")
        XCTAssertEqual(layout.confirmButton.imageWithTitleView?.title, R.string.localizable.commonSign(preferredLanguages: languages))
    }

    func testLayoutWithoutRawDataHandlerIgnoresTheTap() {
        let layout = WalletConnectConfirmationViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        layout.perform(NSSelectorFromString("handleRawDataTapped"))
        var taps = 0
        layout.rawDataOnTap = { taps += 1 }
        layout.perform(NSSelectorFromString("handleRawDataTapped"))
        XCTAssertEqual(taps, 1)
        XCTAssertTrue(layout.rawDataView.isUserInteractionEnabled)
        XCTAssertTrue(layout.rowViews.isEmpty)
        layout.locale = Locale(identifier: "en")
        XCTAssertEqual(layout.rawDataView.titleLabel.text, R.string.localizable.commonTransactionRawData(preferredLanguages: languages))
    }

    func testRouterPresentsAllDoneAndRawData() throws {
        let router = WalletConnectConfirmationRouter()
        let host = try CovJHostedView()
        defer { host.close() }
        router.showAllDone(chain: CovJWcFixture.evmChain(), hashString: "0xfeed", view: host) {}
        let allDone = try XCTUnwrap(host.presented as? AllDoneViewController)
        XCTAssertEqual(allDone.modalPresentationStyle, .custom)

        let rawHost = try CovJHostedView()
        defer { rawHost.close() }
        router.showRawData(json: .stringValue("payload"), from: rawHost)
        XCTAssertTrue(rawHost.presented is RawDataViewController)

        router.showRawData(json: .null, from: nil)
        router.showAllDone(chain: CovJWcFixture.evmChain(), hashString: nil, view: nil) {}
        XCTAssertTrue(rawHost.presented is RawDataViewController, "Without a view nothing else is presented")
        XCTAssertTrue(host.presented is AllDoneViewController)
    }
}

final class CovJWcConfirmationInteractorTests: XCTestCase {
    private func makeInteractor(
        method: WalletConnectMethod,
        service: CovJWcServiceStub,
        signer: CovJWcSignerStub = CovJWcSignerStub(),
        authorizer: CovJWcAuthorizerStub = CovJWcAuthorizerStub(),
        allowed: @escaping (Blockchain) -> Bool = { _ in true }
    ) throws -> WalletConnectConfirmationInteractor {
        WalletConnectConfirmationInteractor(
            walletConnect: service,
            inputData: CovJWcFixture.inputData(try CovJWcFixture.signingRequest(method: method)),
            signer: signer,
            authorizer: authorizer,
            isSigningAllowed: allowed
        )
    }

    func testRejectSendsTheUserRejection() async throws {
        let service = CovJWcServiceStub()
        let interactor = try makeInteractor(method: .ethereumPersonalSign, service: service)
        let output = CovJWcConfirmationInteractorOutputStub()
        interactor.setup(with: output)
        try await interactor.reject()
        guard case let .rejected(request, error) = try XCTUnwrap(service.signDecisions.all.first) else {
            return XCTFail("Expected a rejection")
        }
        XCTAssertEqual(request.method, "personal_sign")
        XCTAssertEqual(error.code, 4001)
    }

    func testSignedTransactionKeepsItsHashWhenTheDAppStoppedWaiting() async throws {
        let service = CovJWcServiceStub()
        service.failure = WalletConnectClient.ClientError.requestNotFound
        let signer = CovJWcSignerStub()
        let interactor = try makeInteractor(method: .ethereumSendTransaction, service: service, signer: signer)
        let hash = try await interactor.approve()
        XCTAssertEqual(hash, "0xsigned")
        XCTAssertEqual(signer.signed.all, ["eth_sendTransaction"])
        XCTAssertEqual(service.signDecisions.count, 1)
        XCTAssertEqual(service.pendingChecks.count, 2, "Checked before the PIN and again before signing")
    }

    func testSignatureNobodyWaitsForEndsTheRequest() async throws {
        let service = CovJWcServiceStub()
        service.failure = WalletConnectClient.ClientError.sessionNotFound
        let interactor = try makeInteractor(method: .ethereumPersonalSign, service: service)
        do {
            _ = try await interactor.approve()
            XCTFail("A message signature the dApp never gets was not given")
        } catch {
            XCTAssertEqual(error as? WalletConnectSigningError, .requestEnded)
        }
        XCTAssertEqual(service.signDecisions.count, 1)
    }

    func testMessageSignatureReturnsNoHash() async throws {
        let service = CovJWcServiceStub()
        let interactor = try makeInteractor(method: .ethereumSignTypeDataV4, service: service)
        let hash = try await interactor.approve()
        XCTAssertNil(hash)
        guard case let .signed(request, signature) = try XCTUnwrap(service.signDecisions.all.first) else {
            return XCTFail("Expected a signature")
        }
        XCTAssertEqual(request.method, "eth_signTypedData_v4")
        XCTAssertEqual(try signature.get(String.self), "0xsigned")
    }

    func testChecksAfterThePinStopSigning() async throws {
        let checks = CovJWcCalls<Int>()
        let signer = CovJWcSignerStub()
        let authorizer = CovJWcAuthorizerStub()
        let paused = try makeInteractor(
            method: .ethereumPersonalSign, service: CovJWcServiceStub(), signer: signer, authorizer: authorizer,
            allowed: { _ in
                checks.append(1)
                return checks.count == 1
            }
        )
        do {
            _ = try await paused.approve()
            XCTFail("Signing paused while the PIN screen was up")
        } catch {
            XCTAssertEqual(error as? WalletConnectSigningError, .paused)
        }
        XCTAssertEqual(authorizer.asks.count, 1)

        let service = CovJWcServiceStub()
        service.pendingLimit = 1
        let ended = try makeInteractor(method: .ethereumPersonalSign, service: service, signer: signer, authorizer: authorizer)
        do {
            _ = try await ended.approve()
            XCTFail("The request ended while the PIN screen was up")
        } catch {
            XCTAssertEqual(error as? WalletConnectSigningError, .requestEnded)
        }
        XCTAssertEqual(authorizer.asks.count, 2)
        XCTAssertTrue(signer.signed.all.isEmpty)
        XCTAssertTrue(service.signDecisions.all.isEmpty)
    }
}
