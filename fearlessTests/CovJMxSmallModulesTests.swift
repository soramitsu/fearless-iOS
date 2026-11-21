import XCTest
import UIKit
import SoraFoundation
@testable import fearless

// MARK: - About

final class CovJMxAboutView: UIViewController, AboutViewProtocol {
    var states: [AboutViewState] = []
    var locales: [Locale] = []
    func didReceive(state: AboutViewState) { states.append(state) }
    func didReceive(locale: Locale) { locales.append(locale) }
}

final class CovJMxAboutWireframe: AboutWireframeProtocol {
    var canSendEmail = true
    var webs: [(URL, WebPresentableStyle)] = []
    var emails: [SocialMessage] = []
    var licenses: [Locale] = []
    var messages: [(String?, String, String?)] = []

    func showFontLicenses(from _: AboutViewProtocol, locale: Locale) { licenses.append(locale) }
    func showWeb(url: URL, from _: ControllerBackedProtocol, style: WebPresentableStyle) { webs.append((url, style)) }

    func writeEmail(with message: SocialMessage, from _: ControllerBackedProtocol, completionHandler _: EmailComposerCompletion?) -> Bool {
        emails.append(message)
        return canSendEmail
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append((message, title, closeAction))
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
}

final class CovJMxAboutPresenterTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    func testLoadShowsEveryAboutRowInTheSelectedLanguage() throws {
        let (presenter, wireframe) = try makePresenter()
        let view = CovJMxAboutView()

        presenter.didLoad(view: view)

        XCTAssertEqual(view.locales.map(\.identifier), ["en"])
        guard case let .loaded(items) = view.states.last else {
            return XCTFail("Expected loaded rows")
        }
        XCTAssertEqual(items.count, AboutViewModelFactory(about: Self.about).createAboutItemViewModels(locale: locale).count)
        XCTAssertEqual(items.first?.title, R.string.localizable.aboutWebsite(preferredLanguages: locale.rLanguages))

        presenter.applyLocalization()
        XCTAssertEqual(view.states.count, 2)
        XCTAssertEqual(view.locales.count, 2)
        XCTAssertTrue(wireframe.webs.isEmpty)
    }

    func testActionsNeedAViewAndOpenLinksLicensesAndEmail() throws {
        let (presenter, wireframe) = try makePresenter()
        let url = try XCTUnwrap(URL(string: "https://example.invalid/about"))

        presenter.activate(url: url)
        presenter.activateFontLicenses()
        presenter.activateWriteUs()
        XCTAssertTrue(wireframe.webs.isEmpty)
        XCTAssertTrue(wireframe.licenses.isEmpty)
        XCTAssertTrue(wireframe.emails.isEmpty)

        let view = CovJMxAboutView()
        presenter.didLoad(view: view)
        presenter.activate(url: url)
        presenter.activateFontLicenses()
        presenter.activateWriteUs()

        XCTAssertEqual(wireframe.webs.map(\.0), [url])
        XCTAssertEqual(wireframe.webs.first?.1, .automatic)
        XCTAssertEqual(wireframe.licenses.map(\.identifier), ["en"])
        XCTAssertEqual(wireframe.emails.first?.recepients, ["support@example.invalid"])
        XCTAssertEqual(wireframe.emails.first?.subject, "Feedback")
        XCTAssertNil(wireframe.emails.first?.body)
        XCTAssertTrue(wireframe.messages.isEmpty)
    }

    func testWriteUsWithoutMailAccountExplainsTheProblem() throws {
        let (presenter, wireframe) = try makePresenter()
        wireframe.canSendEmail = false
        let view = CovJMxAboutView()
        let window = try CovJViewFixture.host(view)
        defer {
            view.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        presenter.didLoad(view: view)

        presenter.activateWriteUs()

        // The four-argument `present(message:title:closeAction:from:)` is the protocol extension, so the sheet is shown
        // on the view rather than recorded by the stub.
        XCTAssertEqual(wireframe.emails.count, 1)
        XCTAssertTrue(wireframe.messages.isEmpty)
        XCTAssertTrue(view.presentedViewController is SheetAletViewController)
    }

    private static let about: AboutData = {
        let config = ApplicationConfig.shared
        return AboutData(
            websiteUrl: config.websiteURL,
            opensourceUrl: config.opensourceURL,
            twitter: config.twitter,
            youTube: config.youTube,
            instagram: config.instagram,
            medium: config.medium,
            wiki: config.wiki,
            telegram: TelegramData(
                fearlessWallet: config.fearlessWallet,
                fearlessAnnouncements: config.fearlessAnnouncements,
                fearlessHappiness: config.fearlessHappiness
            ),
            writeUs: SupportData(title: "Write", subject: "Feedback", details: "", email: "support@example.invalid"),
            version: "9.9.9",
            legal: LegalData(termsUrl: config.termsURL, privacyPolicyUrl: config.privacyPolicyURL)
        )
    }()

    private func makePresenter() throws -> (AboutPresenter, CovJMxAboutWireframe) {
        let wireframe = CovJMxAboutWireframe()
        let presenter = AboutPresenter(
            about: Self.about,
            wireframe: wireframe,
            aboutViewModelFactory: AboutViewModelFactory(about: Self.about),
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
        return (presenter, wireframe)
    }
}

// MARK: - Purchase

final class CovJMxPurchaseView: UIViewController, PurchaseViewProtocol {}

final class CovJMxPurchaseOutput: PurchaseInteractorOutputProtocol {
    var completions = 0
    func didCompletePurchase() { completions += 1 }
}

final class CovJMxPurchaseInteractor: PurchaseInteractorInputProtocol {
    var setups = 0
    func setup() { setups += 1 }
}

final class CovJMxPurchaseWireframe: PurchaseWireframeProtocol {
    var completions = 0
    func complete(from _: PurchaseViewProtocol?) { completions += 1 }
}

final class CovJMxPurchaseTests: XCTestCase {
    func testFactoryWiresTheProviderPage() throws {
        let url = try XCTUnwrap(URL(string: "https://buy.example.invalid/?wallet=1"))
        let action = PurchaseAction(title: "Provider", url: url, icon: UIImage())

        let view = try XCTUnwrap(PurchaseViewFactory.createView(for: action))

        let controller = try XCTUnwrap(view.controller as? PurchaseViewController)
        let presenter = try XCTUnwrap(controller.presenter as? PurchasePresenter)
        XCTAssertEqual(presenter.action.url, url)
        XCTAssertEqual(presenter.action.title, "Provider")
        XCTAssertTrue(presenter.view === controller)
        XCTAssertTrue(presenter.interactor is PurchaseInteractor)
        XCTAssertTrue(presenter.wireframe is PurchaseWireframe)
    }

    func testPresenterSetsUpAndCompletesThroughItsWireframe() {
        let presenter = PurchasePresenter(action: PurchaseAction(title: "P", url: URL(fileURLWithPath: "/"), icon: UIImage()))
        let interactor = CovJMxPurchaseInteractor()
        let wireframe = CovJMxPurchaseWireframe()
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        presenter.setup()
        presenter.didCompletePurchase()

        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(wireframe.completions, 1)
    }

    func testInteractorReportsCompletedPurchases() {
        let eventCenter = EventCenter()
        let interactor = PurchaseInteractor(eventCenter: eventCenter)
        let output = CovJMxPurchaseOutput()
        interactor.presenter = output

        interactor.setup()
        eventCenter.notify(with: PurchaseCompleted())

        XCTAssertTrue(CovJWait.until { output.completions == 1 })
    }

    func testWireframeClosesThePurchasePage() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer { window.isHidden = true }
        let page = CovJMxPurchaseView()
        root.present(page, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === page && !page.isBeingPresented })
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))

        PurchaseWireframe(localizationManager: manager).complete(from: page)

        // The page closes and the screen that opened it shows the completion alert.
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController.map { $0 !== page } ?? false })
        CovJWait.drain(0.1)
        XCTAssertNil(page.presentingViewController)
        PurchaseWireframe(localizationManager: manager).complete(from: nil)
    }
}

// MARK: - Interaction

final class CovJMxInteractionTests: XCTestCase {
    func testDismissClosureIsStoredPerControllerAndReplaceable() {
        let controller = UIViewController()
        let other = UIViewController()
        var calls: [String] = []

        controller.onInteractionDismiss()
        controller.addOnInteractionDismiss { calls.append("first") }
        controller.onInteractionDismiss()
        controller.addOnInteractionDismiss { calls.append("second") }
        controller.onInteractionDismiss()
        other.onInteractionDismiss()

        XCTAssertEqual(calls, ["first", "second"])
    }
}

// MARK: - Receive

final class CovJMxAccountInfoAdapter: AccountInfoSubscriptionAdapterProtocol {
    var subscriptions: [[ChainAsset]] = []
    weak var handler: AccountInfoSubscriptionAdapterHandler?
    var queues: [DispatchQueue?] = []

    func subscribe(
        chainAsset _: ChainAsset,
        accountId _: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscriptions.append(chainsAssets)
        self.handler = handler
        queues.append(queue)
    }

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}

final class CovJMxReceiveOutput: ReceiveAndRequestAssetInteractorOutput {
    var results: [(Bool, String)] = []
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        if case .success = result {
            results.append((true, chainAsset.asset.symbol))
        } else {
            results.append((false, chainAsset.asset.symbol))
        }
    }
}

final class CovJMxReceiveInteractorTests: XCTestCase {
    func testOnlySoraSubscribesToEveryAssetOfItsChain() throws {
        let other = CovJFixture.chainAsset(chainName: "Kusama", symbol: "KSM")
        let otherAdapter = CovJMxAccountInfoAdapter()
        ReceiveAndRequestAssetInteractor(accountInfoSubscriptionAdapter: otherAdapter, chainAsset: other)
            .setup(with: CovJMxReceiveOutput())
        XCTAssertTrue(otherAdapter.subscriptions.isEmpty)

        let xor = CovJFixture.asset(id: "xor", symbol: "XOR")
        let val = CovJFixture.asset(id: "val", symbol: "VAL", isUtility: false)
        let sora = CovJFixture.chain(name: "SORA Mainnet", assets: [xor, val])
        let adapter = CovJMxAccountInfoAdapter()
        let interactor = ReceiveAndRequestAssetInteractor(
            accountInfoSubscriptionAdapter: adapter,
            chainAsset: ChainAsset(chain: sora, asset: xor)
        )
        let output = CovJMxReceiveOutput()

        interactor.setup(with: output)

        XCTAssertEqual(adapter.subscriptions.count, 1)
        XCTAssertEqual(Set(adapter.subscriptions.first?.map(\.asset.symbol) ?? []), ["XOR", "VAL"])
        XCTAssertTrue(adapter.handler === interactor)
        XCTAssertEqual(adapter.queues.first ?? nil, DispatchQueue.main)

        interactor.handleAccountInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainAsset: ChainAsset(chain: sora, asset: val))
        interactor.handleAccountInfo(result: .failure(CovJError()), accountId: Data(), chainAsset: ChainAsset(chain: sora, asset: xor))
        XCTAssertEqual(output.results.map(\.0), [true, false])
        XCTAssertEqual(output.results.map(\.1), ["VAL", "XOR"])
    }

    func testReceiveViewModelDefaultsToAnEmptyNetworkName() {
        let viewModel = ReceiveAssetViewModel(asset: "XOR", accountName: "Main", address: "cnV", isSora: true)
        XCTAssertEqual(viewModel.networkName, "")
        XCTAssertEqual(viewModel.asset, "XOR")
        XCTAssertTrue(viewModel.isSora)
    }
}

// MARK: - Wallet commands

final class CovJMxWalletCommandFactory: WalletCommandFactoryProtocol {
    var presented: [UIViewController] = []
    var hidden: [WalletDismissAction] = []

    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand {
        presented.append(controller)
        return WalletPresentationCommand(presentingController: controller)
    }

    func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand {
        hidden.append(action)
        return WalletPresentationCommand()
    }
}

final class CovJMxWalletCommandTests: XCTestCase {
    func testSelectAccountFactoryBindsItsCommandFactory() throws {
        let commandFactory = CovJMxWalletCommandFactory()

        let command = WalletSelectAccountCommandFactory().createCommand(commandFactory)

        XCTAssertTrue(command.commandFactory === commandFactory)
    }

    func testPresentationCommandRunsItsCompletionAndDefaultsToAPlainModal() throws {
        let command = WalletPresentationCommand()
        var runs = 0
        command.completionBlock = { runs += 1 }

        try command.execute()

        XCTAssertEqual(runs, 1)
        guard case let .modal(inNavigation) = command.presentationStyle else {
            return XCTFail("Expected a modal presentation")
        }
        XCTAssertFalse(inNavigation)
        command.completionBlock = { throw CovJError("stop") }
        XCTAssertThrowsError(try command.execute())
    }
}
