import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import RobinHood
import SoraFoundation
@testable import fearless

final class CovJAcctConfirmViewStub: UIViewController, AccountConfirmViewProtocol {
    var received: [([String], Bool)] = []
    func didReceive(words: [String], afterConfirmationFail: Bool) { received.append((words, afterConfirmationFail)) }
}

final class CovJAcctConfirmInteractorStub: AccountConfirmInteractorInputProtocol {
    var flow: AccountConfirmFlow?
    var wordRequests = 0
    var confirmations: [[String]] = []
    var skips = 0

    func requestWords() { wordRequests += 1 }
    func confirm(words: [String]) { confirmations.append(words) }
    func skipConfirmation() { skips += 1 }
}

final class CovJAcctConfirmWireframeStub: AccountConfirmWireframeProtocol {
    var proceeds: [AccountConfirmFlow?] = []
    var alerts: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var messages: [String] = []
    var handlesErrors = true

    func proceed(from _: AccountConfirmViewProtocol?, flow: AccountConfirmFlow?) { proceeds.append(flow) }
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }

    func present(
        message _: String?, title: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]
    ) {
        messages.append(title)
    }
}

final class CovJAcctConfirmOutputSpy: AccountConfirmInteractorOutputProtocol {
    var words: [([String], Bool)] = []
    var completions = 0
    var errors: [Error] = []
    func didReceive(words: [String], afterConfirmationFail: Bool) { self.words.append((words, afterConfirmationFail)) }
    func didCompleteConfirmation() { completions += 1 }
    func didReceive(error: Error) { errors.append(error) }
}

/// Records the account operation instead of persisting it.
final class CovJAcctConfirmInteractorProbe: BaseAccountConfirmInteractor {
    var operations = 0
    override func createAccountUsingOperation(_: BaseOperation<MetaAccountModel>) { operations += 1 }
}

final class CovJAcctConfirmPresenterSpy: AccountConfirmPresenterProtocol {
    var loads = 0
    func didLoad(view _: AccountConfirmViewProtocol) { loads += 1 }
    func requestWords() {}
    func confirm(words _: [String]) {}
    func skip() {}
}

final class CovJAcctRootAnimatorSpy: RootControllerAnimationCoordinatorProtocol {
    var controllers: [UIViewController] = []
    func animateTransition(to controller: UIViewController) { controllers.append(controller) }
    func animateTransition(to controller: UIViewController, in _: UIWindow) { controllers.append(controller) }
}

enum CovJAcctConfirmFixture {
    static func mnemonic() throws -> IRMnemonicProtocol {
        try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)
    }

    static func walletFlow() throws -> AccountConfirmFlow {
        .wallet(MetaAccountImportMnemonicRequest(
            mnemonic: try mnemonic(), username: "Confirm", substrateDerivationPath: "", ethereumDerivationPath: "",
            cryptoType: .sr25519, defaultChainId: nil
        ))
    }

    static func chainFlow() throws -> AccountConfirmFlow {
        .chain(ChainAccountImportMnemonicRequest(
            mnemonic: try mnemonic(), username: "Chain", derivationPath: "", cryptoType: .sr25519, isEthereum: false,
            meta: AccountGenerator.generateMetaAccount(), chainId: "chain"
        ))
    }
}

final class CovJAcctConfirmPresenterTests: XCTestCase {
    private var languages: [String]? { LocalizationManager.shared.selectedLocale.rLanguages }

    private func make() -> (AccountConfirmPresenter, CovJAcctConfirmViewStub, CovJAcctConfirmInteractorStub, CovJAcctConfirmWireframeStub) {
        let interactor = CovJAcctConfirmInteractorStub()
        let wireframe = CovJAcctConfirmWireframeStub()
        let presenter = AccountConfirmPresenter(interactor: interactor, wireframe: wireframe, localizationManager: LocalizationManager.shared)
        let view = CovJAcctConfirmViewStub()
        presenter.didLoad(view: view)
        return (presenter, view, interactor, wireframe)
    }

    func testSkipAsksBeforeSkippingAndRequestsWords() throws {
        let (presenter, _, interactor, wireframe) = make()
        XCTAssertEqual(interactor.wordRequests, 1)
        presenter.requestWords()
        XCTAssertEqual(interactor.wordRequests, 2)

        presenter.skip()
        let alert = try XCTUnwrap(wireframe.alerts.first)
        XCTAssertEqual(alert.title, R.string.localizable.backupNotBackedUpTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.backupNotBackedUpMessage(preferredLanguages: languages))
        XCTAssertEqual(alert.actionAxis, .horizontal)
        XCTAssertEqual(alert.actions.map(\.title), [
            R.string.localizable.commonCancel(preferredLanguages: languages),
            R.string.localizable.backupNotBackedUpConfirm(preferredLanguages: languages)
        ])
        XCTAssertNil(alert.actions[0].handler)
        alert.actions[1].handler?()
        XCTAssertEqual(interactor.skips, 1)
    }

    func testConfirmLocksUntilWordsReturnAndMismatchIsReported() throws {
        let (presenter, view, interactor, wireframe) = make()
        let host = try CovJHostedView(controller: view)
        defer { host.close() }

        presenter.confirm(words: ["a", "b"])
        presenter.confirm(words: ["c"])
        presenter.skip()
        presenter.requestWords()
        XCTAssertEqual(interactor.confirmations, [["a", "b"]])
        XCTAssertTrue(wireframe.alerts.isEmpty)
        XCTAssertEqual(interactor.wordRequests, 1)

        presenter.didReceive(words: ["b", "a"], afterConfirmationFail: true)
        XCTAssertEqual(view.received.last?.0, ["b", "a"])
        XCTAssertEqual(view.received.last?.1, true)
        let title = R.string.localizable.confirmMnemonicMismatchErrorTitle(preferredLanguages: languages)
        XCTAssertTrue(wireframe.messages == [title] || (view.presentedViewController ?? host.navigation.presentedViewController) is SheetAletViewController)

        presenter.confirm(words: ["a", "b"])
        XCTAssertEqual(interactor.confirmations.count, 2)
    }

    func testErrorsFallBackAndCompletionProceedsOnce() throws {
        let (presenter, _, interactor, wireframe) = make()
        interactor.flow = try CovJAcctConfirmFixture.walletFlow()

        presenter.didReceive(error: CovJError("save"))
        wireframe.handlesErrors = false
        presenter.didReceive(error: CovJError("again"))
        XCTAssertEqual(wireframe.errors.count, 3)
        guard case .undefined? = wireframe.errors.last as? CommonError else { return XCTFail("Expected the undefined fallback") }

        presenter.didCompleteConfirmation()
        presenter.didCompleteConfirmation()
        presenter.didReceive(error: CovJError("late"))
        presenter.didReceive(words: ["x"], afterConfirmationFail: false)
        XCTAssertEqual(wireframe.proceeds.count, 1)
        guard case .wallet?? = wireframe.proceeds.first else { return XCTFail("Expected the wallet flow") }
        XCTAssertEqual(wireframe.errors.count, 3)
    }

    func testPendingDepartureDefersAndReplaysResults() {
        let (presenter, _, _, wireframe) = make()
        presenter.willLeaveView()
        presenter.didCompleteConfirmation()
        presenter.didReceive(error: CovJError("ignored, success came first"))
        XCTAssertTrue(wireframe.proceeds.isEmpty)
        presenter.didCancelLeavingView()
        XCTAssertEqual(wireframe.proceeds.count, 1)

        let (failing, _, _, failingWireframe) = make()
        failing.willLeaveView()
        failing.didReceive(error: CovJError("deferred"))
        failing.didCancelLeavingView()
        XCTAssertEqual(failingWireframe.errors.first as? CovJError, CovJError("deferred"))
        failing.didCancelLeavingView()
        XCTAssertEqual(failingWireframe.errors.count, 1)

        let (leaving, _, leavingInteractor, leavingWireframe) = make()
        leaving.willLeaveView()
        leaving.didCompleteConfirmation()
        leaving.didLeaveView()
        leaving.didCancelLeavingView()
        leaving.requestWords()
        XCTAssertTrue(leavingWireframe.proceeds.isEmpty)
        XCTAssertEqual(leavingInteractor.wordRequests, 1)

        let spy = CovJAcctConfirmPresenterSpy()
        spy.willLeaveView()
        spy.didCancelLeavingView()
        spy.didLeaveView()
        XCTAssertEqual(spy.loads, 0)
    }
}

final class CovJAcctConfirmInteractorTests: XCTestCase {
    private func make(_ flow: AccountConfirmFlow?) -> (CovJAcctConfirmInteractorProbe, CovJAcctOperationFactoryStub, CovJAcctConfirmOutputSpy) {
        let factory = CovJAcctOperationFactoryStub()
        let interactor = CovJAcctConfirmInteractorProbe(
            flow: flow, accountOperationFactory: factory,
            accountRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()), operationManager: OperationManager()
        )
        let output = CovJAcctConfirmOutputSpy()
        interactor.presenter = output
        return (interactor, factory, output)
    }

    func testWalletConfirmationCreatesAccountOnlyForTheRightOrder() throws {
        let (interactor, factory, output) = make(try CovJAcctConfirmFixture.walletFlow())
        let words = CovJAcctImportHarness.phrase.components(separatedBy: " ")
        interactor.requestWords()
        XCTAssertEqual(output.words.first?.0.sorted(), words.sorted())
        XCTAssertEqual(output.words.first?.1, false)

        interactor.confirm(words: words.reversed())
        XCTAssertEqual(output.words.last?.1, true)
        XCTAssertEqual(interactor.operations, 0)

        interactor.confirm(words: words)
        interactor.skipConfirmation()
        XCTAssertEqual(factory.mnemonicRequests.count, 2)
        XCTAssertEqual(factory.mnemonicRequests.first?.username, "Confirm")
        XCTAssertEqual(interactor.operations, 2)
    }

    func testChainConfirmationImportsChainAccountAndMissingFlowDoesNothing() throws {
        let (interactor, factory, _) = make(try CovJAcctConfirmFixture.chainFlow())
        interactor.confirm(words: CovJAcctImportHarness.phrase.components(separatedBy: " "))
        interactor.skipConfirmation()
        XCTAssertEqual(factory.chainMnemonicRequests.count, 2)
        XCTAssertEqual(factory.chainMnemonicRequests.first?.chainId, "chain")

        let (empty, emptyFactory, emptyOutput) = make(nil)
        empty.skipConfirmation()
        empty.confirm(words: [])
        XCTAssertEqual(empty.operations, 0)
        XCTAssertTrue(emptyFactory.mnemonicRequests.isEmpty)
        XCTAssertEqual(emptyOutput.words.last?.1, true)
        XCTAssertTrue(empty.shuffledWords.isEmpty)
    }

    func testExportConfirmationSkipCompletesOnce() throws {
        let interactor = ExportMnemonicConfirmInteractor(
            mnemonic: try CovJAcctConfirmFixture.mnemonic(), settings: SelectedWalletSettings.shared,
            wallet: AccountGenerator.generateMetaAccount(), eventCenter: CovJAcctEventCenterStub(), recordsWholeWalletBackup: false
        )
        let output = CovJAcctConfirmOutputSpy()
        interactor.presenter = output
        XCTAssertNil(interactor.flow)
        interactor.skipConfirmation()
        interactor.skipConfirmation()
        XCTAssertEqual(output.completions, 1)
    }
}
