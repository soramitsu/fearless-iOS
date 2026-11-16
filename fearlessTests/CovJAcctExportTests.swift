import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import RobinHood
import SoraFoundation
@testable import fearless

final class CovJAcctSeedReaderStub: VerifiedSeedExportReading {
    struct CovJAcctSeedCall: Equatable {
        let metaId: String
        let accountId: Data?
        let publicKey: Data
        let cryptoType: CryptoType
        let ethereumBased: Bool
    }

    var result: Result<VerifiedSeedExport, Error> = .success(VerifiedSeedExport(seed: Data([1, 2, 3]), derivationPath: "//1"))
    private let lock = NSLock()
    private var recorded: [CovJAcctSeedCall] = []
    var calls: [CovJAcctSeedCall] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func fetchSeed(metaId: MetaAccountId, accountId: AccountId?, publicKey: Data, cryptoType: CryptoType, ethereumBased: Bool) throws
        -> VerifiedSeedExport {
        lock.lock()
        recorded.append(CovJAcctSeedCall(metaId: metaId, accountId: accountId, publicKey: publicKey, cryptoType: cryptoType, ethereumBased: ethereumBased))
        lock.unlock()
        return try result.get()
    }
}

final class CovJAcctBackupMarkerStub: WalletBackupMarkerWriting {
    var wallets: [MetaAccountModel] = []
    func recordBackup(of exportedWallet: MetaAccountModel, completion: @escaping (Result<MetaAccountModel, Error>) -> Void) {
        wallets.append(exportedWallet)
        completion(.success(exportedWallet))
    }
}

final class CovJAcctEventCenterStub: EventCenterProtocol {
    var events: [EventProtocol] = []
    func notify(with event: EventProtocol) { events.append(event) }
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovJAcctSeedOutputSpy: ExportSeedInteractorOutputProtocol {
    var exports: [[ExportSeedData]] = []
    var errors: [Error] = []
    func didReceive(exportData: [ExportSeedData], notShown _: [ExportSeedNotShown]) { exports.append(exportData) }
    func didReceive(error: Error) { errors.append(error) }
}

final class CovJAcctExportViewStub: UIViewController, ExportGenericViewProtocol {
    var viewModels: [MultipleExportGenericViewModelProtocol] = []
    var retries: [() -> Void] = []
    func set(viewModel: MultipleExportGenericViewModelProtocol) { viewModels.append(viewModel) }
    func showBackupStatusFailure(retry: @escaping () -> Void) { retries.append(retry) }
}

final class CovJAcctPlainExportViewStub: UIViewController, ExportGenericViewProtocol {
    var viewModels = 0
    func set(viewModel _: MultipleExportGenericViewModelProtocol) { viewModels += 1 }
}

class CovJAcctExportWireframeBase: SheetAlertPresentable, ErrorPresentable, SharingPresentable {
    var alerts: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var handlesErrors = true
    var backs = 0

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { alerts.append(viewModel) }
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }

    func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}
    func share(sources _: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}
    func back(view _: ExportGenericViewProtocol?) { backs += 1 }
}

final class CovJAcctSeedWireframeStub: CovJAcctExportWireframeBase, ExportSeedWireframeProtocol {
    func showJsonExport(flow _: ExportFlow, from _: ExportGenericViewProtocol?) {}
}

final class CovJAcctMnemonicWireframeStub: CovJAcctExportWireframeBase, ExportMnemonicWireframeProtocol {
    var confirmations: [String] = []
    func close(view _: ExportGenericViewProtocol?) {}
    func showJsonExport(flow _: ExportFlow, from _: ExportGenericViewProtocol?) {}
    func openConfirmationForMnemonic(_ mnemonic: IRMnemonicProtocol, wallet _: MetaAccountModel, from _: ExportGenericViewProtocol?) {
        confirmations.append(mnemonic.toString())
    }
}

final class CovJAcctMnemonicInteractorStub: ExportMnemonicInteractorInputProtocol {
    var walletFetches = 0
    func fetchExportDataForWallet(wallet _: MetaAccountModel, accounts _: [ChainAccountInfo]) { walletFetches += 1 }
    func fetchExportDataForAddress(_: String, chain _: ChainModel, wallet _: MetaAccountModel) {}
}

final class CovJAcctMnemonicOutputSpy: ExportMnemonicInteractorOutputProtocol {
    var exports: [[ExportMnemonicData]] = []
    var errors: [Error] = []
    func didReceive(exportDatas: [ExportMnemonicData]) { exports.append(exportDatas) }
    func didReceive(error: Error) { errors.append(error) }
}

final class CovJAcctExportSeedInteractorTests: XCTestCase {
    private func make() -> (ExportSeedInteractor, CovJAcctSeedReaderStub, CovJAcctSeedOutputSpy) {
        let reader = CovJAcctSeedReaderStub()
        let output = CovJAcctSeedOutputSpy()
        let interactor = ExportSeedInteractor(
            seedReader: reader, backupMarker: CovJAcctBackupMarkerStub(), operationManager: OperationManager(),
            chainRepository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>()), eventCenter: CovJAcctEventCenterStub()
        )
        interactor.presenter = output
        return (interactor, reader, output)
    }

    func testAddressExportReadsVerifiedSeedOfTheWalletAccount() throws {
        let (interactor, reader, output) = make()
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJFixture.chain(name: "Westend", addressPrefix: 42)
        let address = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.toAddress())

        interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)

        XCTAssertTrue(CovJWait.until { !output.exports.isEmpty })
        let export = try XCTUnwrap(output.exports.first?.first)
        XCTAssertEqual(export.seed, Data([1, 2, 3]))
        XCTAssertEqual(export.derivationPath, "//1")
        XCTAssertEqual(export.chain.chainId, chain.chainId)
        XCTAssertEqual(export.cryptoType, .sr25519)
        let call = try XCTUnwrap(reader.calls.first)
        XCTAssertEqual(call.metaId, wallet.metaId)
        XCTAssertNil(call.accountId, "A wallet-level account is read without a chain account id")
        XCTAssertEqual(call.publicKey, wallet.substratePublicKey)
        XCTAssertFalse(call.ethereumBased)
    }

    func testAddressExportOfChainAccountPassesItsAccountIdAndReportsReaderErrors() throws {
        let (interactor, reader, output) = make()
        reader.result = .failure(CovJError("seed replaced"))
        let chain = CovJFixture.chain(name: "Kusama", addressPrefix: 2)
        let accountId = try XCTUnwrap(Data.random(of: 32))
        let chainAccount = ChainAccountModel(
            chainId: chain.chainId, accountId: accountId, publicKey: try XCTUnwrap(Data.random(of: 32)), cryptoType: 1, ethereumBased: false
        )
        let wallet = AccountGenerator.generateMetaAccount(with: [chainAccount])
        let address = try accountId.toAddress(using: .substrate(chain.addressPrefix))

        interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)

        XCTAssertTrue(CovJWait.until { !output.errors.isEmpty })
        XCTAssertEqual(output.errors.first as? CovJError, CovJError("seed replaced"))
        XCTAssertEqual(reader.calls.first?.accountId, accountId)
        XCTAssertEqual(reader.calls.first?.cryptoType, .ed25519)
        XCTAssertTrue(output.exports.isEmpty)
    }

    func testUnknownAddressReportsMissingAccount() throws {
        let (interactor, reader, output) = make()
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = CovJFixture.chain(addressPrefix: 42)
        let stranger = try XCTUnwrap(Data.random(of: 32)).toAddress(using: .substrate(chain.addressPrefix))

        interactor.fetchExportDataForAddress(stranger, chain: chain, wallet: wallet)

        guard case .missingAccount? = output.errors.first as? ExportMnemonicInteractorError else {
            return XCTFail("Expected missingAccount")
        }
        XCTAssertTrue(reader.calls.isEmpty)
    }
}

final class CovJAcctExportPresenterTests: XCTestCase {
    private var wallet: MetaAccountModel { AccountGenerator.generateMetaAccount() }

    func testSeedPresenterErrorsFallBackToUndefined() {
        let presenter = ExportSeedPresenter(flow: .multiple(wallet: wallet, accounts: []), localizationManager: LocalizationManager.shared)
        let wireframe = CovJAcctSeedWireframeStub()
        presenter.wireframe = wireframe

        presenter.didReceive(error: CovJError("one"))
        wireframe.handlesErrors = false
        presenter.didReceive(error: CovJError("two"))

        XCTAssertEqual(wireframe.errors.count, 3)
        XCTAssertEqual(wireframe.errors.first as? CovJError, CovJError("one"))
        guard case .undefined? = wireframe.errors.last as? CommonError else { return XCTFail("Expected the undefined fallback") }
    }

    func testMnemonicPresenterShowsWordsAndErrorsUntilLeaving() throws {
        let flow = ExportFlow.multiple(wallet: wallet, accounts: [])
        let presenter = ExportMnemonicPresenter(flow: flow, localizationManager: LocalizationManager.shared)
        let wireframe = CovJAcctMnemonicWireframeStub()
        let interactor = CovJAcctMnemonicInteractorStub()
        let view = CovJAcctExportViewStub()
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)
        let data = ExportMnemonicData(mnemonic: mnemonic, derivationPath: "//1", cryptoType: .sr25519, chain: CovJFixture.chain())

        presenter.activateAccessoryOption()
        presenter.didReceive(exportDatas: [data])
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertEqual(view.viewModels.first?.viewModels.count, 1)
        XCTAssertEqual(presenter.exportDatas?.count, 1)

        presenter.didReceive(error: CovJError("read"))
        wireframe.handlesErrors = false
        presenter.didReceive(error: CovJError("read again"))
        XCTAssertEqual(wireframe.errors.count, 3)

        presenter.activateExport()
        XCTAssertEqual(wireframe.confirmations, [CovJAcctImportHarness.phrase])

        presenter.didLeaveView()
        presenter.didReceive(exportDatas: [data])
        presenter.didReceive(error: CovJError("late"))
        presenter.setup()
        XCTAssertEqual(view.viewModels.count, 1)
        XCTAssertEqual(wireframe.errors.count, 3)
        XCTAssertNil(presenter.exportDatas)
        XCTAssertEqual(interactor.walletFetches, 0)
    }

    func testMnemonicOutputDefaultRoutesEmptyExportToFirstError() throws {
        let output = CovJAcctMnemonicOutputSpy()
        let chain = CovJFixture.chain()
        output.didReceive(exportDatas: [], notShown: [ExportMnemonicNotShown(chain: chain, error: CovJError("hidden"))])
        XCTAssertEqual(output.errors.first as? CovJError, CovJError("hidden"))
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: CovJAcctImportHarness.phrase)
        output.didReceive(
            exportDatas: [ExportMnemonicData(mnemonic: mnemonic, derivationPath: nil, cryptoType: nil, chain: chain)],
            notShown: [ExportMnemonicNotShown(chain: chain, error: CovJError("other"))]
        )
        XCTAssertEqual(output.exports.count, 1)
        XCTAssertEqual(output.errors.count, 1)
        output.didReceive(exportDatas: [], notShown: [])
        XCTAssertEqual(output.exports.count, 2)

        CovJAcctMnemonicInteractorStub().cancelExport()
        let wireframe = CovJAcctMnemonicWireframeStub()
        wireframe.openConfirmationForMnemonic(mnemonic, wallet: wallet, backupProof: nil, from: nil)
        XCTAssertEqual(wireframe.confirmations, [CovJAcctImportHarness.phrase])
    }

    func testExportFlowSelectsOneBaseAccountPerFamilyAndEveryChainAccount() {
        let meta = wallet
        func info(_ name: String, ethereum: Bool, chainAccount: Bool) -> ChainAccountInfo {
            let chain = CovJFixture.chain(name: name, options: ethereum ? [.ethereumBased] : nil)
            let response = ChainAccountResponse(
                chainId: chain.chainId, accountId: Data(repeating: 1, count: 32), publicKey: Data(repeating: 2, count: 32),
                name: meta.name, cryptoType: ethereum ? .ecdsa : .sr25519, addressPrefix: chain.addressPrefix,
                isEthereumBased: ethereum, isChainAccount: chainAccount, walletId: meta.metaId
            )
            return ChainAccountInfo(chain: chain, account: response)
        }
        let accounts = [
            info("A", ethereum: false, chainAccount: false), info("B", ethereum: false, chainAccount: false),
            info("C", ethereum: true, chainAccount: false), info("D", ethereum: true, chainAccount: false),
            info("E", ethereum: false, chainAccount: true)
        ]
        let flow = ExportFlow.multiple(wallet: meta, accounts: accounts)
        XCTAssertEqual(flow.exportingAccounts.map(\.chain.name), ["A", "C", "E"])
        XCTAssertEqual(flow.wallet.metaId, meta.metaId)

        let single = ExportFlow.single(chain: accounts[0].chain, address: "addr", wallet: meta)
        XCTAssertTrue(single.exportingAccounts.isEmpty)
        XCTAssertEqual(single.wallet.metaId, meta.metaId)
    }

    func testGenericExportDefaults() throws {
        struct CovJAcctMinimalExportPresenter: ExportGenericPresenterProtocol {
            let flow: ExportFlow
            let counter: CovJAcctCounter
            func didLoadView() { counter.value += 1 }
            func setup() { counter.value += 10 }
        }
        let counter = CovJAcctCounter()
        let presenter = CovJAcctMinimalExportPresenter(flow: .multiple(wallet: wallet, accounts: []), counter: counter)
        presenter.didLeaveView()
        presenter.activateAccessoryOption()
        presenter.activateExport()
        presenter.didTapExportSubstrateButton()
        presenter.didTapExportEthereumButton()
        presenter.didTapStringExport("value")
        XCTAssertEqual(counter.value, 0)

        var retried = 0
        let plain = CovJAcctPlainExportViewStub()
        plain.showBackupStatusFailure { retried += 1 }
        let recording = CovJAcctExportViewStub()
        let wireframe = CovJAcctSeedWireframeStub()
        wireframe.presentBackupStatusFailure(from: recording, locale: CovJFixture.locale) { retried += 1 }
        XCTAssertEqual(recording.retries.count, 1)
        recording.retries.first?()
        XCTAssertEqual(retried, 1)

        let host = try CovJHostedView()
        defer { host.close() }
        let view = CovJAcctExportViewStub()
        host.navigation.pushViewController(UIViewController(), animated: false)
        host.navigation.pushViewController(view, animated: false)
        wireframe.close(view: view)
        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })
    }
}

final class CovJAcctCounter {
    var value = 0
}
