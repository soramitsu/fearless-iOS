import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraKeystore
@testable import fearless

final class CovJMxOptionView: UIViewController, WalletOptionViewInput {
    var visibility: [Bool] = []
    func setDeleteButtonIsVisible(_ isVisible: Bool) { visibility.append(isVisible) }
}

final class CovJMxOptionInteractor: WalletOptionInteractorInput {
    weak var output: WalletOptionInteractorOutput?
    var deletions = 0
    func setup(with output: WalletOptionInteractorOutput) { self.output = output }
    func deleteWallet() { deletions += 1 }
}

final class CovJMxOptionRouter: CovJSheetSpy, WalletOptionRouterInput {
    var details: [MetaAccountModel] = []
    var exports: [ManagedMetaAccountModel] = []
    var renames: [MetaAccountModel] = []
    var scores: [String?] = []
    var dismissals = 0
    func showWalletDetails(from _: ControllerBackedProtocol?, for wallet: MetaAccountModel) { details.append(wallet) }
    func showExportWallet(from _: ControllerBackedProtocol?, wallet: ManagedMetaAccountModel) { exports.append(wallet) }
    func showChangeWalletName(from _: ControllerBackedProtocol?, for wallet: MetaAccountModel) { renames.append(wallet) }
    func presentAccountScore(address: String?, from _: ControllerBackedProtocol?) { scores.append(address) }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJMxOptionAuthorizer: SubmissionAuthorizing {
    var grants = true
    var requests = 0
    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(grants)
    }
}

final class CovJMxOptionOutput: WalletOptionInteractorOutput, WalletOptionModuleOutput {
    var visibility: [Bool] = []
    var removed = 0
    var moduleRemoved = 0
    func setDeleteButtonIsVisible(_ isVisible: Bool) { visibility.append(isVisible) }
    func walletRemoved() { removed += 1 }
    func walletWasRemoved() { moduleRemoved += 1 }
}

final class CovJMxOptionDisconnect: WalletConnectDisconnectService {
    var wallets: [String] = []
    var failure: Error?
    func disconnect(wallet: MetaAccountModel) async throws {
        wallets.append(wallet.metaId)
        if let failure { throw failure }
    }

    func disconnectAllSessions() {}
}

final class CovJMxOptionViewOutput: WalletOptionViewOutput {
    var events: [String] = []
    func didLoad(view _: WalletOptionViewInput) { events.append("load") }
    func walletDetailsDidTap() { events.append("details") }
    func exportWalletDidTap() { events.append("export") }
    func deleteWalletDidTap() { events.append("delete") }
    func changeWalletNameDidTap() { events.append("rename") }
    func accountScoreDidTap() { events.append("score") }
}

final class CovJMxWalletOptionPresenterTests: XCTestCase {
    private let wallet = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: true, order: 3)
    private var view = CovJMxOptionView()
    private var interactor = CovJMxOptionInteractor()
    private var router = CovJMxOptionRouter()
    private var authorizer = CovJMxOptionAuthorizer()
    private var eventCenter = EventCenter()

    override func setUp() {
        super.setUp()
        view = CovJMxOptionView()
        interactor = CovJMxOptionInteractor()
        router = CovJMxOptionRouter()
        authorizer = CovJMxOptionAuthorizer()
        eventCenter = EventCenter()
    }

    func testOptionsRouteWithTheWallet() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)

        presenter.walletDetailsDidTap()
        presenter.exportWalletDidTap()
        presenter.changeWalletNameDidTap()
        presenter.accountScoreDidTap()

        XCTAssertEqual(router.details.map(\.metaId), [wallet.info.metaId])
        XCTAssertEqual(router.exports, [wallet])
        XCTAssertEqual(router.renames.map(\.metaId), [wallet.info.metaId])
        XCTAssertEqual(router.scores, [wallet.info.ethereumAddress?.toHex(includePrefix: true)])
    }

    func testInteractorOutputsReachTheViewAndRouterOnMain() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.setDeleteButtonIsVisible(false)
        presenter.walletRemoved()

        XCTAssertTrue(CovJWait.until { self.view.visibility == [false] && self.router.dismissals == 1 })
    }

    func testDeleteAsksForConfirmationAndDeletesOnlyAfterAuthorization() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        presenter.deleteWalletDidTap()

        let sheet = try XCTUnwrap(router.sheets.last)
        let languages = Locale(identifier: "en").rLanguages
        XCTAssertEqual(sheet.title, R.string.localizable.accountDeleteConfirmationTitle(preferredLanguages: languages))
        XCTAssertEqual(sheet.message, R.string.localizable.accountDeleteConfirmationDescription(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [
            R.string.localizable.commonCancel(preferredLanguages: languages),
            R.string.localizable.accountDeleteConfirm(preferredLanguages: languages)
        ])
        XCTAssertNil(sheet.closeAction)
        XCTAssertNil(sheet.actions.first?.handler)
        let remove = try XCTUnwrap(sheet.actions.last?.handler)

        authorizer.grants = false
        remove()
        XCTAssertEqual(interactor.deletions, 0)

        authorizer.grants = true
        remove()
        XCTAssertEqual(interactor.deletions, 1)
        XCTAssertEqual(authorizer.requests, 2)
    }

    func testWalletEventsKeepTheShownWalletUpToDate() throws {
        let presenter = try makePresenter()
        presenter.didLoad(view: view)

        eventCenter.notify(with: WalletNameChanged(wallet: wallet.info.replacingName("Renamed")))
        eventCenter.notify(with: WalletNameChanged(wallet: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(CovJWait.until {
            presenter.walletDetailsDidTap()
            return self.router.details.last?.name == "Renamed"
        })
        CovJWait.drain(0.1)
        presenter.walletDetailsDidTap()
        XCTAssertEqual(router.details.last?.name, "Renamed")

        eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet.info.replacingName("Changed")))
        XCTAssertTrue(CovJWait.until {
            presenter.exportWalletDidTap()
            return self.router.exports.last?.info.name == "Changed"
        })
        XCTAssertEqual(router.exports.last?.isSelected, true)
        XCTAssertEqual(router.exports.last?.order, 3)

        eventCenter.notify(with: SelectedAccountChanged(account: wallet.info.replacingName("Selected")))
        eventCenter.notify(with: SelectedAccountChanged(account: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(CovJWait.until {
            presenter.changeWalletNameDidTap()
            return self.router.renames.last?.name == "Selected"
        })
        CovJWait.drain(0.1)
        presenter.applyLocalization()
        presenter.changeWalletNameDidTap()
        XCTAssertEqual(router.renames.last?.metaId, wallet.info.metaId)
        XCTAssertEqual(router.renames.last?.name, "Selected")
    }

    private func makePresenter() throws -> WalletOptionPresenter {
        WalletOptionPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")),
            eventCenter: eventCenter,
            submissionAuthorizer: authorizer
        )
    }
}

final class CovJMxWalletOptionInteractorTests: XCTestCase {
    func testDeleteButtonIsHiddenForTheSelectedWalletOrWithoutSelection() {
        let selected = SelectedWalletSettings.shared.value
        let other = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let output = CovJMxOptionOutput()

        makeInteractor(wallet: other, repository: CovJMemoryRepository()).setup(with: output)

        XCTAssertEqual(output.visibility, selected == nil ? [false] : [])

        if let selected {
            let current = CovJMxOptionOutput()
            makeInteractor(wallet: ManagedMetaAccountModel(info: selected), repository: CovJMemoryRepository()).setup(with: current)
            XCTAssertEqual(current.visibility, [false])
        }
    }

    func testDeleteRemovesTheRowDisconnectsAndReportsRemoval() {
        let wallet = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let kept = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let repository = CovJMemoryRepository([wallet, kept])
        let disconnect = CovJMxOptionDisconnect()
        let output = CovJMxOptionOutput()
        let interactor = makeInteractor(wallet: wallet, repository: repository, disconnect: disconnect, moduleOutput: output)
        interactor.setup(with: output)

        interactor.deleteWallet()

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.removed == 1 && output.moduleRemoved == 1 })
        XCTAssertEqual(repository.items, [kept])
        XCTAssertEqual(disconnect.wallets, [wallet.info.metaId])
    }

    func testFailedDeletionStillDisconnectsAndClosesTheOptions() {
        let wallet = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())
        let repository = CovJMemoryRepository([wallet])
        repository.failure = CovJError("disk")
        let disconnect = CovJMxOptionDisconnect()
        disconnect.failure = CovJError("relay")
        let output = CovJMxOptionOutput()
        let interactor = makeInteractor(wallet: wallet, repository: repository, disconnect: disconnect, moduleOutput: output)
        interactor.setup(with: output)

        interactor.deleteWallet()

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.removed == 1 && output.moduleRemoved == 1 })
        XCTAssertEqual(repository.items, [wallet])
        XCTAssertEqual(disconnect.wallets, [wallet.info.metaId])
    }

    private func makeInteractor(
        wallet: ManagedMetaAccountModel,
        repository: CovJMemoryRepository<ManagedMetaAccountModel>,
        disconnect: CovJMxOptionDisconnect = CovJMxOptionDisconnect(),
        moduleOutput: WalletOptionModuleOutput? = nil
    ) -> WalletOptionInteractor {
        WalletOptionInteractor(
            wallet: wallet,
            metaAccountRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            moduleOutput: moduleOutput,
            walletConnectDisconnectService: disconnect,
            secretEraser: WalletSecretEraser(keystore: InMemoryKeychain(), storedTags: { [] })
        )
    }
}

final class CovJMxWalletOptionViewTests: XCTestCase {
    func testControllerForwardsEveryOptionAndTogglesDelete() throws {
        let output = CovJMxOptionViewOutput()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = WalletOptionViewController(output: output, localizationManager: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = try XCTUnwrap(controller.view as? WalletOptionViewLayout)

        XCTAssertEqual(layout.titleLabel.text, R.string.localizable.walletOptionsTitle(preferredLanguages: manager.selectedLocale.rLanguages))
        layout.walletDetailsButton.sendActions(for: .touchUpInside)
        layout.backupWalletButton.sendActions(for: .touchUpInside)
        layout.deleteWalletButton.sendActions(for: .touchUpInside)
        layout.changeWalletNameButton.sendActions(for: .touchUpInside)
        layout.accountScoreButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.events, ["load", "details", "export", "delete", "rename", "score"])

        controller.setDeleteButtonIsVisible(false)
        XCTAssertTrue(layout.deleteWalletButton.isHidden)
        controller.setDeleteButtonIsVisible(true)
        XCTAssertFalse(layout.deleteWalletButton.isHidden)
    }

    func testRouterPresentsTheRenameScreen() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer {
            root.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let host = CovJMxOptionView()
        root.present(host, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === host && !host.isBeingPresented })

        WalletOptionRouter().showChangeWalletName(from: host, for: AccountGenerator.generateMetaAccount())

        XCTAssertTrue(CovJWait.until(timeout: 3) { host.presentedViewController is WalletNameViewController })
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.presentedViewController?.isBeingPresented == false })
        host.dismiss(animated: false)
    }
}
