import XCTest
import UIKit
import SSFModels
import RobinHood
import SoraFoundation
@testable import fearless

final class CovJAcctExportPasswordViewStub: UIViewController, AccountExportPasswordViewProtocol {
    var password: InputViewModelProtocol?
    var confirmation: InputViewModelProtocol?
    var errors: [AccountExportPasswordError] = []

    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol) { password = viewModel }
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol) { confirmation = viewModel }
    func set(error: AccountExportPasswordError) { errors.append(error) }
}

final class CovJAcctExportPasswordWireframeStub: AccountExportPasswordWireframeProtocol {
    var exports: [[RestoreJson]] = []
    var backs = 0
    var errors: [Error] = []
    var alerts: [SheetAlertPresentableViewModel] = []
    var handlesErrors = true

    func showJSONExport(_ jsons: [RestoreJson], flow _: ExportFlow, from _: AccountExportPasswordViewProtocol?) { exports.append(jsons) }
    func back(from _: ControllerBackedProtocol?) { backs += 1 }
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }
}

final class CovJAcctExportPasswordInteractorStub: AccountExportPasswordInteractorInputProtocol {
    var walletExports: [(MetaAccountModel, [ChainAccountInfo], String)] = []
    var accountExports: [(String, String, ChainModel.Id)] = []

    func exportWallet(wallet: MetaAccountModel, accounts: [ChainAccountInfo], password: String) {
        walletExports.append((wallet, accounts, password))
    }

    func exportAccount(address: String, password: String, chain: ChainModel, wallet _: MetaAccountModel) {
        accountExports.append((address, password, chain.chainId))
    }
}

final class CovJAcctExportPasswordOutputSpy: AccountExportPasswordInteractorOutputProtocol {
    var exports: [[RestoreJson]] = []
    var errors: [Error] = []
    func didExport(jsons: [RestoreJson]) { exports.append(jsons) }
    func didReceive(error: Error) { errors.append(error) }
}

/// Leaves every optional presenter callback to the protocol's defaults.
final class CovJAcctMinimalPasswordPresenter: AccountExportPasswordPresenterProtocol {
    let flow: ExportFlow
    var setups = 0
    var proceeds = 0
    init(flow: ExportFlow) { self.flow = flow }
    func setup() { setups += 1 }
    func proceed() { proceeds += 1 }
}

final class CovJAcctLeavingPasswordPresenter: AccountExportPasswordPresenterProtocol {
    let flow: ExportFlow
    var cancels = 0
    var leaves = 0
    init(flow: ExportFlow) { self.flow = flow }
    func setup() {}
    func proceed() {}
    func didCancelLeavingView() { cancels += 1 }
    func didLeaveView() { leaves += 1 }
}

final class CovJAcctKeystoreExportStub: KeystoreExportWrapperProtocol {
    private let lock = NSLock()
    private var hashes: [String?] = []
    var genesisHashes: [String?] {
        lock.lock()
        defer { lock.unlock() }
        return hashes
    }

    func export(
        chainAccount _: ChainAccountResponse, password _: String?, address: String, metaId _: String, accountId _: AccountId?,
        genesisHash: String?
    ) throws -> Data {
        lock.lock()
        hashes.append(genesisHash)
        lock.unlock()
        return Data("{\"address\":\"\(address)\"}".utf8)
    }
}

final class CovJAcctExtrinsicFactoryStub: ExtrinsicOperationFactoryProtocol {
    var genesis: Result<String, Error> = .success("0xgenesis")

    private func failing<T>() -> CompoundOperationWrapper<T> {
        CompoundOperationWrapper(targetOperation: ClosureOperation<T> { throw CovJError("not used") })
    }

    func estimateFeeOperation(_: @escaping ExtrinsicBuilderIndexedClosure, numberOfExtrinsics _: Int)
        -> CompoundOperationWrapper<[FeeExtrinsicResult]> { failing() }

    func submit(_: @escaping ExtrinsicBuilderIndexedClosure, signer _: SigningWrapperProtocol, numberOfExtrinsics _: Int)
        -> CompoundOperationWrapper<[SubmitExtrinsicResult]> { failing() }

    func submitAndWatch(_: @escaping ExtrinsicBuilderClosure, signer _: SigningWrapperProtocol)
        -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> { failing() }

    func createGenesisBlockHashOperation() -> BaseOperation<String> {
        let genesis = genesis
        return ClosureOperation { try genesis.get() }
    }
}

final class CovJAcctExportPasswordPresenterTests: XCTestCase {
    private func make(flow: ExportFlow) -> (
        AccountExportPasswordPresenter, CovJAcctExportPasswordViewStub, CovJAcctExportPasswordInteractorStub, CovJAcctExportPasswordWireframeStub
    ) {
        let presenter = AccountExportPasswordPresenter(flow: flow, localizationManager: LocalizationManager.shared)
        let view = CovJAcctExportPasswordViewStub()
        let interactor = CovJAcctExportPasswordInteractorStub()
        let wireframe = CovJAcctExportPasswordWireframeStub()
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        presenter.setup()
        return (presenter, view, interactor, wireframe)
    }

    func testSingleAccountExportValidatesPasswordsFirst() {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJFixture.chain(name: "Westend")
        let (presenter, view, interactor, wireframe) = make(flow: .single(chain: chain, address: "5Address", wallet: wallet))

        view.password?.inputHandler.changeValue(to: "short")
        presenter.proceed()
        view.password?.inputHandler.changeValue(to: "long enough password")
        view.confirmation?.inputHandler.changeValue(to: "different password")
        presenter.proceed()
        XCTAssertEqual(view.errors, [.passwordTooShort, .passwordMismatch])
        XCTAssertTrue(interactor.accountExports.isEmpty)

        view.confirmation?.inputHandler.changeValue(to: "long enough password")
        presenter.proceed()
        presenter.proceed()
        XCTAssertEqual(interactor.accountExports.count, 1)
        XCTAssertEqual(interactor.accountExports.first?.0, "5Address")
        XCTAssertEqual(interactor.accountExports.first?.1, "long enough password")
        XCTAssertEqual(interactor.accountExports.first?.2, chain.chainId)

        presenter.didReceive(error: CovJError("export"))
        wireframe.handlesErrors = false
        presenter.proceed()
        presenter.didReceive(error: CovJError("again"))
        XCTAssertEqual(wireframe.errors.count, 3)
        guard case .undefined? = wireframe.errors.last as? CommonError else { return XCTFail("Expected the undefined fallback") }
        XCTAssertEqual(interactor.accountExports.count, 2)
    }

    func testProtocolDefaultsAndLeavingRoute() {
        let flow = ExportFlow.multiple(wallet: AccountGenerator.generateMetaAccount(), accounts: [])
        let minimal = CovJAcctMinimalPasswordPresenter(flow: flow)
        minimal.didAppearView()
        minimal.willLeaveView()
        minimal.didCancelLeavingView()
        minimal.didLeaveView()
        minimal.didFinishLeavingView(cancelled: true)
        XCTAssertEqual(minimal.setups, 0)
        XCTAssertEqual(minimal.proceeds, 0)

        let leaving = CovJAcctLeavingPasswordPresenter(flow: flow)
        leaving.didFinishLeavingView(cancelled: true)
        leaving.didFinishLeavingView(cancelled: false)
        XCTAssertEqual(leaving.cancels, 1)
        XCTAssertEqual(leaving.leaves, 1)

        let view = CovJAcctExportPasswordViewStub()
        view.setExporting(true)
        XCTAssertTrue(view.errors.isEmpty)
    }

    func testErrorTextsAndBatchDescription() {
        let languages = CovJFixture.locale.rLanguages
        let mismatch = AccountExportPasswordError.passwordMismatch.toErrorContent(for: CovJFixture.locale)
        XCTAssertEqual(mismatch.title, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages))
        XCTAssertEqual(mismatch.message, R.string.localizable.commonErrorPasswordMismatch(preferredLanguages: languages))
        let short = AccountExportPasswordError.passwordTooShort.toErrorContent(for: nil)
        XCTAssertFalse(short.message.isEmpty)
        XCTAssertTrue(short.message.contains("\(NSPredicate.backupPasswordMinimumLength)"))
        XCTAssertEqual(AccountExportBatchError(available: [], unavailable: []).errorDescription, "Some accounts could not be exported.")
    }
}

final class CovJAcctExportPasswordInteractorTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("covj-acct-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func make(_ extrinsic: CovJAcctExtrinsicFactoryStub) -> (AccountExportPasswordInteractor, CovJAcctKeystoreExportStub, CovJAcctExportPasswordOutputSpy) {
        let wrapper = CovJAcctKeystoreExportStub()
        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: wrapper,
            accountRepository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()),
            operationManager: OperationManager(),
            extrinsicOperationFactory: extrinsic,
            chainRepository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>()),
            exportDirectory: directory
        )
        let output = CovJAcctExportPasswordOutputSpy()
        interactor.presenter = output
        return (interactor, wrapper, output)
    }

    func testAccountExportStampsTheGenesisHash() throws {
        let (interactor, wrapper, output) = make(CovJAcctExtrinsicFactoryStub())
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJFixture.chain(name: "Westend", addressPrefix: 42)
        let address = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.toAddress())

        interactor.exportAccount(address: address, password: "pw", chain: chain, wallet: wallet)

        XCTAssertTrue(CovJWait.until(timeout: 3) { !output.exports.isEmpty || !output.errors.isEmpty })
        XCTAssertTrue(output.errors.isEmpty)
        let json = try XCTUnwrap(output.exports.first?.first)
        XCTAssertEqual(json.chain.chainId, chain.chainId)
        XCTAssertTrue(json.data.contains(address))
        XCTAssertEqual(wrapper.genesisHashes, ["0xgenesis"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: json.fileURL.path))
    }

    func testFailedGenesisLookupIsReported() throws {
        let extrinsic = CovJAcctExtrinsicFactoryStub()
        extrinsic.genesis = .failure(CovJError("node offline"))
        let (interactor, wrapper, output) = make(extrinsic)
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJFixture.chain(addressPrefix: 42)
        let address = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.toAddress())

        interactor.exportAccount(address: address, password: "pw", chain: chain, wallet: wallet)

        XCTAssertTrue(CovJWait.until(timeout: 3) { !output.errors.isEmpty })
        XCTAssertEqual(output.errors.first as? CovJError, CovJError("node offline"))
        XCTAssertTrue(wrapper.genesisHashes.isEmpty)
        XCTAssertTrue(output.exports.isEmpty)
    }
}
