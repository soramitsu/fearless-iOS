import XCTest
import TonSwift
import UIKit
import SoraUI
@testable import fearless
import SoraKeystore
import RobinHood
import SoraFoundation
import Cuckoo
import IrohaCrypto
import SSFModels
import SSFUtils
import CoreData

class AccountExportPasswordTests: XCTestCase {
    func testSuccessfullExport() throws {
        // given

        let facade = UserDataStorageTestFacade()
        let keychain = InMemoryKeychain()

        let accountsRepository = AccountRepositoryFactory.createRepository(for: facade)
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        try AccountCreationHelper.createMetaAccountFromMnemonic(
            cryptoType: .sr25519,
            keychain: keychain,
            settings: settings
        )
        let wallet = try XCTUnwrap(settings.value)

        let view = MockAccountExportPasswordViewProtocol()
        view.enableDefaultImplementation(AccountExportPasswordViewProtocolStub())
        let wireframe = MockAccountExportPasswordWireframeProtocol()

        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(0))
        let walletAddress = try AddressFactory.address(for: try XCTUnwrap(wallet.substrateAccountId), chain: chain)

        let presenter = AccountExportPasswordPresenter(
            flow: .single(chain: chain, address: walletAddress, wallet: wallet),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe

        let exportWrapper = KeystoreExportWrapper(keystore: keychain)
        let exportOperationQueue = OperationQueue()
        exportOperationQueue.qualityOfService = .userInitiated
        let exportOperationManager = OperationManager(operationQueue: exportOperationQueue)
        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: exportWrapper,
            accountRepository: AnyDataProviderRepository(accountsRepository),
            operationManager: exportOperationManager,
            extrinsicOperationFactory: nil,
            chainRepository: AnyDataProviderRepository(chainRepository)
        )
        presenter.interactor = interactor
        interactor.presenter = presenter

        var inputViewModel: InputViewModelProtocol?
        var confirmationViewModel: InputViewModelProtocol?

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.setPasswordInputViewModel(any(InputViewModelProtocol.self))).then { viewModel in
                inputViewModel = viewModel
            }

            when(stub.setPasswordConfirmationViewModel(any(InputViewModelProtocol.self))).then { viewModel in
                confirmationViewModel = viewModel
            }

            when(stub.set(error: any(AccountExportPasswordError.self))).thenDoNothing()
        }

        let expectation = expectation(description: "JSON export is presented")

        stub(wireframe) { stub in
            when(
                stub
                    .present(
                        viewModel: any(SheetAlertPresentableViewModel.self),
                        from: any(ControllerBackedProtocol?.self)
                    )
            ).thenDoNothing()

            when(stub.showJSONExport(
                any([RestoreJson].self),
                flow: any(ExportFlow.self),
                from: any(AccountExportPasswordViewProtocol?.self)
            )).then { _ in
                expectation.fulfill()
            }
            when(stub.present(
                message: any(String?.self),
                title: any(String.self),
                closeAction: any(String?.self),
                from: any(ControllerBackedProtocol?.self),
                actions: any([SheetAlertPresentableAction].self)
            )).then { _ in
                XCTFail()
            }
        }

        let saveOperation = accountsRepository.saveOperation({ [wallet] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        // when

        presenter.setup()

        inputViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)
        confirmationViewModel?.inputHandler.changeValue(to: Constants.validSrKeystorePassword)

        presenter.proceed()

        // then

        wait(for: [expectation], timeout: 15)
    }
}

/// Drives the real export interactor. All bytes are disposable public test material.
final class AccountExportBatchTests: XCTestCase {
    private enum FixtureError: Error { case unavailable }

    private final class Exporter: KeystoreExportWrapperProtocol {
        var requests: [String] = []
        var result: (Int) throws -> Data = { index in Data("{\"publicFixture\":\(index)}".utf8) }
        func export(
            chainAccount _: ChainAccountResponse, password _: String?, address: String,
            metaId _: String, accountId _: AccountId?, genesisHash _: String?
        ) throws -> Data {
            requests.append(address)
            return try result(requests.count - 1)
        }
    }

    private final class Output: AccountExportPasswordInteractorOutputProtocol {
        let completion: XCTestExpectation
        var exports: [[RestoreJson]] = []
        var errors: [Error] = []
        init(_ completion: XCTestExpectation) { self.completion = completion }
        func didExport(jsons: [RestoreJson]) {
            XCTAssertTrue(Thread.isMainThread)
            exports.append(jsons)
            completion.fulfill()
        }

        func didReceive(error: Error) {
            XCTAssertTrue(Thread.isMainThread)
            errors.append(error)
            completion.fulfill()
        }
    }

    private struct Fixture {
        let interactor: AccountExportPasswordInteractor
        let wallet: MetaAccountModel
        let accounts: [ChainAccountInfo]
        let output: Output
        let urls: [URL]
        let directory: URL
    }

    private func fixture(
        exporter: KeystoreExportWrapperProtocol, count: Int = 2,
        wallet providedWallet: MetaAccountModel? = nil, accounts providedAccounts: [ChainAccountInfo]? = nil
    ) throws -> Fixture {
        let facade = UserDataStorageTestFacade()
        let wallet = providedWallet ?? AccountGenerator.generateMetaAccount()
        let accounts = providedAccounts ?? (0 ..< count).map { index -> ChainAccountInfo in
            let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(index))
            let account = ChainAccountResponse(
                chainId: chain.chainId, accountId: wallet.substrateAccountId!, publicKey: wallet.substratePublicKey!,
                name: "Public export fixture", cryptoType: .sr25519, addressPrefix: chain.addressPrefix,
                isEthereumBased: false, isChainAccount: false, walletId: wallet.metaId
            )
            return ChainAccountInfo(chain: chain, account: account)
        }
        let urls = try accounts.map { info in
            URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(try AddressFactory.address(for: info.account.accountId, chain: info.chain) + ".json")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("public-export-test-" + UUID().uuidString)
        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: exporter,
            accountRepository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: facade)),
            operationManager: OperationManager(operationQueue: OperationQueue()),
            extrinsicOperationFactory: nil,
            chainRepository: AnyDataProviderRepository(ChainRepositoryFactory().createRepository(
                sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
            )),
            exportDirectory: directory
        )
        let output = Output(expectation(description: "batch outcome"))
        interactor.presenter = output
        return Fixture(interactor: interactor, wallet: wallet, accounts: accounts, output: output, urls: urls, directory: directory)
    }

    private func perform(_ fixture: Fixture, accounts: [ChainAccountInfo]? = nil) async {
        fixture.interactor.exportWallet(wallet: fixture.wallet, accounts: accounts ?? fixture.accounts, password: "public-export-password")
        await fulfillment(of: [fixture.output.completion], timeout: 5)
    }

    private func clean(_ fixture: Fixture) {
        try? FileManager.default.removeItem(at: fixture.directory)
    }

    func testBulkExportReportsMissingKeyInsteadOfSilentlyReturningPartialBackup() async throws {
        let exporter = Exporter()
        exporter.result = { index in
            if index == 1 { throw FixtureError.unavailable }
            return Data("{\"publicFixture\":0}".utf8)
        }
        let f = try fixture(exporter: exporter)
        defer { clean(f) }
        await perform(f)
        XCTAssertTrue(f.output.exports.isEmpty, "A partial batch must not report ordinary complete-export success")
        XCTAssertEqual(f.output.errors.count, 1, "The unavailable account must be surfaced")
        let error = try XCTUnwrap(f.output.errors.first as? AccountExportBatchError)
        XCTAssertEqual(error.unavailable.map { $0.chain.chainId }, [f.accounts[1].chain.chainId])
        XCTAssertEqual(error.available.count, 1)
        XCTAssertEqual(try String(contentsOf: error.available[0].fileURL, encoding: .utf8), error.available[0].data)
    }

    func testBulkExportRejectsInvalidUTF8InsteadOfSilentlyDroppingAccount() async throws {
        let exporter = Exporter()
        exporter.result = { _ in Data([0xFF]) }
        let f = try fixture(exporter: exporter)
        defer { clean(f) }
        await perform(f)
        XCTAssertTrue(f.output.exports.isEmpty)
        XCTAssertEqual(f.output.errors.count, 1)
    }

    func testBulkExportReportsFileWriteFailureInsteadOfEmptySuccess() async throws {
        let f = try fixture(exporter: Exporter(), count: 1)
        // A regular file cannot contain the per-export directory. This exercises
        // a real filesystem failure, not a stubbed success/error callback.
        try Data("public write obstruction".utf8).write(to: f.directory)
        defer { clean(f) }
        await perform(f)
        XCTAssertTrue(f.output.exports.isEmpty)
        XCTAssertEqual(f.output.errors.count, 1)
    }

    func testBulkExportRejectsEmptyRequestedAccountSet() async throws {
        let f = try fixture(exporter: Exporter())
        defer { clean(f) }
        await perform(f, accounts: [])
        XCTAssertTrue(f.output.exports.isEmpty)
        XCTAssertEqual(f.output.errors.count, 1)
    }

    func testActualBatchExportRoundTripsHistoricalSubstrateAndIndependentEthereumKeys() async throws {
        let keychain = InMemoryKeychain()
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let bundle = Bundle(for: Self.self)
        let substrateURL = try XCTUnwrap(bundle.url(forResource: Constants.validSrKeystoreName, withExtension: "json"))
        let ethereumURL = try XCTUnwrap(bundle.url(forResource: Constants.validEthereumKeystoreName, withExtension: "json"))
        try AccountCreationHelper.createMetaAccountFromKeystoreData(
            substrateData: Data(contentsOf: substrateURL), ethereumData: Data(contentsOf: ethereumURL),
            substratePassword: Constants.validSrKeystorePassword, ethereumPassword: Constants.validEthereumKeystorePassword,
            keychain: keychain, settings: settings, cryptoType: .sr25519
        )
        let wallet = try XCTUnwrap(settings.value)
        let accounts = try [false, true].map { ethereum -> ChainAccountInfo in
            let base = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 42)
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
            object["options"] = ethereum ? ["ethereumBased"] : []
            let chain = try JSONDecoder().decode(ChainModel.self, from: JSONSerialization.data(withJSONObject: object))
            let account = ChainAccountResponse(
                chainId: chain.chainId, accountId: try XCTUnwrap(ethereum ? wallet.ethereumAddress : wallet.substrateAccountId),
                publicKey: try XCTUnwrap(ethereum ? wallet.ethereumPublicKey : wallet.substratePublicKey), name: wallet.name,
                cryptoType: ethereum ? .ecdsa : .sr25519, addressPrefix: 42, isEthereumBased: ethereum,
                isChainAccount: false, walletId: wallet.metaId
            )
            return ChainAccountInfo(chain: chain, account: account)
        }
        let tags = [
            fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: nil),
            fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        ]
        let originals = try tags.map { try keychain.fetchKey(for: $0) }
        let f = try fixture(exporter: KeystoreExportWrapper(keystore: keychain), wallet: wallet, accounts: accounts)
        defer { clean(f) }
        await perform(f)
        XCTAssertTrue(f.output.errors.isEmpty)
        let exports = try XCTUnwrap(f.output.exports.first)
        XCTAssertEqual(exports.count, 2)
        for (index, exported) in exports.enumerated() {
            let bytes = try Data(contentsOf: exported.fileURL)
            XCTAssertEqual(String(data: bytes, encoding: .utf8), exported.data)
            let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: bytes)
            let recovered = try KeystoreExtractor().extractFromDefinition(definition, password: "public-export-password")
            XCTAssertEqual(recovered.secretKeyData, originals[index])
            XCTAssertEqual(recovered.publicKeyData, accounts[index].account.publicKey)
            XCTAssertEqual(recovered.cryptoType, accounts[index].account.cryptoType)
            XCTAssertEqual(recovered.address, try AddressFactory.address(for: accounts[index].account.accountId, chain: accounts[index].chain))
            XCTAssertEqual(exported.accountId, accounts[index].account.accountId)
            XCTAssertEqual(definition.encoding.type, ["scrypt", "xsalsa20-poly1305"])
            XCTAssertEqual(try keychain.fetchKey(for: tags[index]), originals[index])
        }
    }

    func testLaterExportCannotReplaceBytesOwnedByEarlierShareModel() async throws {
        let first = try fixture(exporter: Exporter(), count: 1)
        defer { clean(first) }
        await perform(first)
        let earlier = try XCTUnwrap(first.output.exports.first?.first)
        let exporter = Exporter()
        exporter.result = { _ in Data("different encrypted backup bytes".utf8) }
        let second = try fixture(exporter: exporter, wallet: first.wallet, accounts: first.accounts)
        defer { clean(second) }
        await perform(second)
        let later = try XCTUnwrap(second.output.exports.first?.first)
        XCTAssertNotEqual(earlier.fileURL, later.fileURL, "Each share must retain its own encrypted file")
        XCTAssertEqual(try String(contentsOf: earlier.fileURL, encoding: .utf8), earlier.data)
        XCTAssertEqual(try String(contentsOf: later.fileURL, encoding: .utf8), later.data)
    }

    func testSameAddressOnTwoChainsKeepsBothExportedFiles() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let accounts = (0 ..< 2).map { _ -> ChainAccountInfo in
            let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
            let account = ChainAccountResponse(
                chainId: chain.chainId, accountId: wallet.substrateAccountId!, publicKey: wallet.substratePublicKey!,
                name: "Public chain-specific backup", cryptoType: .sr25519, addressPrefix: chain.addressPrefix,
                isEthereumBased: false, isChainAccount: true, walletId: wallet.metaId
            )
            return ChainAccountInfo(chain: chain, account: account)
        }
        let f = try fixture(exporter: Exporter(), wallet: wallet, accounts: accounts)
        defer { clean(f) }
        await perform(f)
        let models = try XCTUnwrap(f.output.exports.first)
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(Set(models.map(\.fileURL)).count, 2)
        for model in models { XCTAssertEqual(try String(contentsOf: model.fileURL, encoding: .utf8), model.data) }
    }

    func testCompleteBulkExportReturnsEveryWrittenFileInRequestedOrder() async throws {
        let f = try fixture(exporter: Exporter())
        defer { clean(f) }
        await perform(f)
        XCTAssertTrue(f.output.errors.isEmpty)
        let jsons = try XCTUnwrap(f.output.exports.first)
        XCTAssertEqual(jsons.count, f.accounts.count)
        XCTAssertEqual(jsons.map { $0.fileURL.lastPathComponent }, f.urls.map(\.lastPathComponent))
        XCTAssertTrue(jsons.allSatisfy { $0.fileURL.path.hasPrefix(f.directory.path + "/") })
        for (index, json) in jsons.enumerated() {
            XCTAssertEqual(json.chain.chainId, f.accounts[index].chain.chainId)
            XCTAssertEqual(json.data, "{\"publicFixture\":\(index)}")
            XCTAssertEqual(try String(contentsOf: XCTUnwrap(json.fileURL), encoding: .utf8), json.data)
        }
    }
}

@MainActor
final class ExportRestoreJsonOwnershipTests: XCTestCase {
    private final class Backup: ExportRestoreJsonInteractorProtocol {
        var completions = 0
        func walletDidBackuped(completion: @escaping (Result<Void, Error>) -> Void) { completions += 1; completion(.success(())) }
    }

    private final class Sharing {
        var selection: ModalPickerSelectionCallback?
        var sources: [[Any]] = []
        var completions: [SharingCompletionHandler?] = []
    }

    private struct Fixture {
        let presenter: ExportRestoreJsonPresenter
        let backup: Backup
        let sharing: Sharing
        let models: [RestoreJson]
    }

    private func fixture(modelCount: Int = 3, requestedCount: Int = 3, single: Bool = false) throws -> Fixture {
        let wallet = AccountGenerator.generateMetaAccount()
        let accounts = try (0 ..< requestedCount).map { index -> ChainAccountInfo in
            let base = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(index))
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
            object["options"] = index == 2 ? ["ethereumBased"] : []
            let chain = try JSONDecoder().decode(ChainModel.self, from: JSONSerialization.data(withJSONObject: object))
            let account = ChainAccountResponse(
                chainId: chain.chainId, accountId: Data(repeating: UInt8(index + 1), count: index == 2 ? 20 : 32),
                publicKey: Data(repeating: UInt8(index + 1), count: 32), name: "Public account \(index)",
                cryptoType: index == 2 ? .ecdsa : .sr25519, addressPrefix: chain.addressPrefix,
                isEthereumBased: index == 2, isChainAccount: true, walletId: wallet.metaId
            )
            return ChainAccountInfo(chain: chain, account: account)
        }
        let requested = modelCount == requestedCount ? accounts : [accounts[0], accounts[2]]
        let models = requested.prefix(modelCount).enumerated().map { index, info in
            RestoreJson(
                data: "{\"publicBackup\":\(index)}",
                chain: info.chain,
                cryptoType: info.account.cryptoType,
                fileURL: URL(fileURLWithPath: "/tmp/public-export-\(index).json"), accountId: info.account.accountId
            )
        }
        let flow: ExportFlow = single
            ? .single(chain: accounts[0].chain, address: "public-account", wallet: wallet)
            : .multiple(wallet: wallet, accounts: accounts)
        let presenter = ExportRestoreJsonPresenter(models: models, flow: flow, localizationManager: LocalizationManager.shared)
        let backup = Backup()
        let sharing = Sharing()
        let wireframe = MockExportRestoreJsonWireframeProtocol()
        stub(wireframe) { stub in
            when(stub.presentExportActionsFlow(
                from: any(ControllerBackedProtocol?.self), items: any([JsonExportAction].self),
                callback: any(ModalPickerSelectionCallback.self)
            )).then { parameters in sharing.selection = parameters.2 }
            when(stub.share(
                sources: any([Any].self), from: any(ControllerBackedProtocol?.self),
                with: any(SharingCompletionHandler?.self)
            )).then { parameters in
                sharing.sources.append(parameters.0)
                sharing.completions.append(parameters.2)
            }
        }
        presenter.interacror = backup
        presenter.wireframe = wireframe
        return Fixture(presenter: presenter, backup: backup, sharing: sharing, models: models)
    }

    private func select(_ index: Int, in fixture: Fixture, ethereum: Bool = false, completed: Bool = true) throws {
        if ethereum { fixture.presenter.didTapExportEthereumButton() }
        else { fixture.presenter.didTapExportSubstrateButton() }
        try XCTUnwrap(fixture.sharing.selection)(index)
        try XCTUnwrap(fixture.sharing.completions.last ?? nil)(completed)
    }

    func testActualExportScreenRoutesEveryFileThroughVisibleGroupButtons() async throws {
        let f = try fixture()
        let uiFactory = UIFactory()
        let controller = ExportGenericViewController(
            uiFactory: uiFactory, binder: ExportGenericViewModelBinder(uiFactory: uiFactory),
            mainTitle: LocalizableResource { R.string.localizable.accountExportAction(preferredLanguages: $0.rLanguages) },
            accessoryTitle: nil
        )
        controller.presenter = f.presenter
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: "en"))
        f.presenter.view = controller
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        window.rootViewController = FearlessNavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try? await Task.sleep(nanoseconds: 200_000_000)
        window.layoutIfNeeded()
        func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
        let buttons = descendants(controller.view).compactMap { $0 as? TriangularedButton }
        for (title, expected) in [
            (R.string.localizable.exportSubstrateTitle(preferredLanguages: ["en"]), Array(f.models.prefix(2))),
            (R.string.localizable.exportEthereumTitle(preferredLanguages: ["en"]), [f.models[2]])
        ] {
            let button = try XCTUnwrap(buttons.first { $0.imageWithTitleView?.title == title })
            var ancestor = button.superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                    break
                }
                ancestor = view.superview
            }
            window.layoutIfNeeded()
            let frame = button.convert(button.bounds, to: window)
            let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
            XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
            let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            })
            attachment.name = "actual-backup-export-" + title
            attachment.lifetime = .keepAlways
            add(attachment)
            button.sendActions(for: .touchUpInside)
            try XCTUnwrap(f.sharing.selection)(0)
            XCTAssertEqual(f.sharing.sources.last as? [URL], expected.map(\.fileURL))
            try XCTUnwrap(f.sharing.completions.last ?? nil)(true)
        }
        XCTAssertEqual(f.backup.completions, 1)
    }

    func testFileExportIncludesEveryChainSpecificAccountInGroup() throws {
        let f = try fixture()
        try select(0, in: f)
        XCTAssertEqual(f.sharing.sources[0] as? [URL], Array(f.models.prefix(2)).map(\.fileURL))
        XCTAssertEqual(f.backup.completions, 0)
        try select(0, in: f, ethereum: true)
        XCTAssertEqual(f.sharing.sources[1] as? [URL], [f.models[2].fileURL])
        XCTAssertEqual(f.backup.completions, 1)
    }

    func testTextExportIncludesEveryChainSpecificAccountInGroup() throws {
        let f = try fixture()
        try select(1, in: f)
        XCTAssertEqual(f.sharing.sources[0] as? [String], Array(f.models.prefix(2)).map(\.data))
    }

    func testIncompleteInventoryCannotMarkWalletBackedUp() throws {
        let f = try fixture(modelCount: 2)
        try select(0, in: f)
        try select(0, in: f, ethereum: true)
        XCTAssertEqual(f.backup.completions, 0)
    }

    func testSingleEcosystemWalletCompletesAfterItsOnlyGroupIsShared() throws {
        let f = try fixture(modelCount: 1, requestedCount: 1)
        try select(0, in: f)
        XCTAssertEqual(f.backup.completions, 1)
    }

    func testSingleAccountExportDoesNotClaimWholeWalletBackup() throws {
        let f = try fixture(modelCount: 1, requestedCount: 1, single: true)
        try select(0, in: f)
        XCTAssertEqual(f.backup.completions, 0)
    }

    func testCancelledShareAndRepeatedCompletionDoNotAdvanceBackupIncorrectly() throws {
        let f = try fixture()
        try select(0, in: f, completed: false)
        try select(0, in: f, ethereum: true)
        XCTAssertEqual(f.backup.completions, 0)
        try select(0, in: f)
        XCTAssertEqual(f.backup.completions, 1)
        try XCTUnwrap(f.sharing.completions.last ?? nil)(true)
        XCTAssertEqual(f.backup.completions, 1)
    }
}

@MainActor
final class AccountExportPartialWarningTests: XCTestCase {
    private final class Capture {
        var sheets: [SheetAlertPresentableViewModel] = []
        var exports: [([RestoreJson], ExportFlow)] = []
    }

    private func fixture(language: String = "en", available: Bool = true) throws
        -> (AccountExportPasswordPresenter, Capture, AccountExportBatchError) {
        let wallet = AccountGenerator.generateMetaAccount()
        let accounts = (0 ..< 3).map { index -> ChainAccountInfo in
            let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: UInt16(index))
            let account = ChainAccountResponse(
                chainId: chain.chainId, accountId: Data(repeating: UInt8(index + 1), count: 32),
                publicKey: Data(repeating: UInt8(index + 1), count: 32), name: "Public backup \(index)",
                cryptoType: .sr25519, addressPrefix: chain.addressPrefix,
                isEthereumBased: false, isChainAccount: true, walletId: wallet.metaId
            )
            return ChainAccountInfo(chain: chain, account: account)
        }
        let models = available ? [RestoreJson(
            data: "public encrypted fixture",
            chain: accounts[0].chain,
            cryptoType: .sr25519,
            fileURL: URL(fileURLWithPath: "/tmp/public-available.json"),
            accountId: accounts[0].account.accountId
        )] : []
        let presenter = AccountExportPasswordPresenter(
            flow: .multiple(wallet: wallet, accounts: accounts),
            localizationManager: try XCTUnwrap(LocalizationManager(localization: language))
        )
        let capture = Capture()
        let wireframe = MockAccountExportPasswordWireframeProtocol()
        stub(wireframe) { stub in
            when(stub.present(
                viewModel: any(SheetAlertPresentableViewModel.self),
                from: any(ControllerBackedProtocol?.self)
            )).then { capture.sheets.append($0.0) }
            when(stub.showJSONExport(
                any([RestoreJson].self),
                flow: any(ExportFlow.self),
                from: any(AccountExportPasswordViewProtocol?.self)
            )).then {
                capture.exports.append(($0.0, $0.1))
            }
        }
        presenter.wireframe = wireframe
        return (presenter, capture, AccountExportBatchError(available: models, unavailable: Array(accounts.dropFirst())))
    }

    func testPartialExportRequiresExplicitActionAndRetainsWholeRequestedInventory() throws {
        let (presenter, capture, error) = try fixture()
        presenter.didReceive(error: error)
        let sheet = try XCTUnwrap(capture.sheets.first)
        XCTAssertTrue(capture.exports.isEmpty)
        XCTAssertEqual(sheet.title, "Backup incomplete")
        XCTAssertTrue(try XCTUnwrap(sheet.message).contains("does not complete this wallet’s backup"))
        for info in error.unavailable {
            XCTAssertTrue(try XCTUnwrap(sheet.message).contains(AddressFactory.address(for: info.account.accountId, chain: info.chain)))
        }
        XCTAssertEqual(sheet.actions.count, 1)
        XCTAssertNotNil(sheet.closeAction)
        try XCTUnwrap(sheet.actions.first?.handler)()
        XCTAssertEqual(capture.exports.count, 1)
        XCTAssertEqual(capture.exports[0].0.map(\.fileURL), error.available.map(\.fileURL))
        XCTAssertEqual(capture.exports[0].1.exportingAccounts.map { $0.account.accountId }, presenter.flow.exportingAccounts.map { $0.account.accountId })
    }

    func testNoAvailableFilesOffersOnlyClose() throws {
        let (presenter, capture, error) = try fixture(available: false)
        presenter.didReceive(error: error)
        XCTAssertEqual(capture.sheets.count, 1)
        XCTAssertTrue(try XCTUnwrap(capture.sheets.first).actions.isEmpty)
        XCTAssertNotNil(capture.sheets.first?.closeAction)
        XCTAssertTrue(capture.exports.isEmpty)
    }

    func testEverySupportedLocaleHasCompletePartialBackupCopy() throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            let (presenter, capture, error) = try fixture(language: language)
            presenter.didReceive(error: error)
            let model = try XCTUnwrap(capture.sheets.first)
            let bundle = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))))
            XCTAssertEqual(model.title, bundle.localizedString(forKey: "export.json.partial.title", value: nil, table: "Localizable"))
            XCTAssertFalse(model.title.contains("export.json.partial"))
            XCTAssertFalse(try XCTUnwrap(model.message).contains("%@"))
            XCTAssertFalse(try XCTUnwrap(model.message).contains("export.json.partial"))
            XCTAssertFalse(try XCTUnwrap(model.actions.first).title.contains("export.json.partial"))
        }
    }

    func testActualPartialWarningIsReadableAndActionReachable() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let (presenter, capture, error) = try fixture(language: language)
                presenter.didReceive(error: error)
                let model = try XCTUnwrap(capture.sheets.first)
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                let host = UIViewController()
                window.rootViewController = host
                window.makeKeyAndVisible()
                window.layoutIfNeeded()
                let controller = SheetAletViewController(viewModel: model)
                controller.modalPresentationStyle = .custom
                controller.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
                // Wait for the custom presentation completion. Its animator can
                // still be active on older runtimes when a fixed delay expires.
                await withCheckedContinuation { continuation in
                    host.present(controller, animated: false) { continuation.resume() }
                }
                window.layoutIfNeeded()
                defer { window.isHidden = true; window.rootViewController = nil }
                let labels = descendants(controller.view).compactMap { $0 as? UILabel }
                let title = try XCTUnwrap(labels.first { $0.text == model.title })
                let message = try XCTUnwrap(labels.first { $0.text == model.message })
                let button = try XCTUnwrap(model.actions.first?.button)
                let image = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                })
                image.name = "actual-partial-export-\(language)-\(category.rawValue)"
                image.lifetime = .keepAlways
                add(image)
                for label in [title, message] {
                    let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 1, "\(language) complete warning text")
                    XCTAssertLessThanOrEqual(label.bounds.width, 320, "\(language) warning text must wrap")
                }
                if let scroll = descendants(controller.view).compactMap({ $0 as? UIScrollView }).first(where: { $0.contentSize.height > $0.bounds.height }) {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                    window.layoutIfNeeded()
                    let messageFrame = message.convert(message.bounds, to: scroll)
                    XCTAssertLessThanOrEqual(messageFrame.maxY, scroll.bounds.maxY + 1, "The complete-backup caveat must be scroll reachable")
                    let end = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    })
                    end.name = "actual-partial-export-bottom-\(language)-\(category.rawValue)"
                    end.lifetime = .keepAlways
                    add(end)
                }
                let frame = button.convert(button.bounds, to: window)
                XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
                XCTAssertLessThanOrEqual(frame.maxY, window.bounds.maxY - window.safeAreaInsets.bottom + 1)
                let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                XCTAssertTrue(
                    hit === button || hit?.isDescendant(of: button) == true,
                    "\(language)/\(category.rawValue): hit=\(String(describing: hit)), button=\(frame), transitioning=\(controller.isBeingPresented), windowInteractive=\(window.isUserInteractionEnabled)"
                )
                button.sendActions(for: .touchUpInside)
                for _ in 0 ..< 100 where host.presentedViewController != nil {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                XCTAssertNil(host.presentedViewController, "Native action dismisses its warning before another presentation")
                XCTAssertEqual(capture.exports.count, 1)
            }
        }
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
}

@MainActor
final class AccountExportPasswordPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]

    private final class Presenter: AccountExportPasswordPresenterProtocol {
        weak var view: AccountExportPasswordViewProtocol?
        let flow: ExportFlow
        let password = InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
        let confirmation = InputViewModel(inputHandler: InputHandler(predicate: NSPredicate.notEmpty))
        var setups = 0
        var proceeds = 0
        init(single: Bool = false) {
            // Public model data only: no keychain, export, encryption or real account is used.
            let wallet = AccountGenerator.generateMetaAccount()
            flow = single
                ? .single(
                    chain: ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0),
                    address: "public-presentation-fixture",
                    wallet: wallet
                )
                : .multiple(wallet: wallet, accounts: [])
        }

        func setup() {
            setups += 1
            view?.setPasswordInputViewModel(password)
            view?.setPasswordConfirmationViewModel(confirmation)
        }

        func proceed() { proceeds += 1 }
    }

    func testExportPasswordBaselineAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let (controller, presenter) = makeController(localization: localization)
                let window = try show(controller, category: category)
                defer { close(window) }
                await settle(window)
                let fields = try inputFields(controller)
                let action = try actionButton(controller)
                let source = try XCTUnwrap(
                    descendants(controller.view).compactMap { $0 as? BorderedSubtitleActionView }
                        .first
                )
                let locale = localization.selectedLocale
                let name = "\(language)-\(category.rawValue)"
                capture(window, name: name + "-empty")
                XCTAssertEqual(presenter.setups, 1)
                XCTAssertEqual(
                    controller.title,
                    R.string.localizable.exportWallet(preferredLanguages: locale.rLanguages)
                )
                XCTAssertFalse(action.isEnabled)
                for (index, field) in fields.enumerated() {
                    XCTAssertTrue(field.textField.isSecureTextEntry)
                    XCTAssertEqual(
                        field.textFont?.pointSize,
                        FWAppearance.accountExportPasswordRestyled
                            ? UIFont.fw(.bodyL, locale: locale, compatibleWith: controller.traitCollection)
                            .pointSize : 14
                    )
                    await reveal(field.textField, in: window)
                    capture(window, name: name + "-field-\(index)")
                    if FWAppearance.accountExportPasswordRestyled {
                        assertLabelsFit(field)
                        assertContained(field.textField, in: field)
                        XCTAssertGreaterThanOrEqual(field.textField.bounds.height, 44)
                        let frame = field.textField.convert(field.textField.bounds, to: window)
                        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                        XCTAssertTrue(hit === field.textField || hit?.isDescendant(of: field.textField) == true)
                    }
                }
                XCTAssertEqual(
                    source.actionControl.contentView.subtitleLabelView.font.pointSize,
                    FWAppearance.accountExportPasswordRestyled
                        ? UIFont.fw(.bodyL, locale: locale, compatibleWith: controller.traitCollection).pointSize : 14
                )
                if FWAppearance.accountExportPasswordRestyled { assertLabelsFit(source) }
                controller.set(error: .passwordMismatch)
                await settle(window)
                let error = try errorLabel(controller, locale: locale)
                await reveal(error, in: window)
                capture(window, name: name + "-error")
                if FWAppearance.accountExportPasswordRestyled {
                    assertContained(error, in: try XCTUnwrap(error.superview))
                    assertLabelsFit(try XCTUnwrap(error.superview))
                }
                await reveal(action, in: window)
                capture(window, name: name + "-action")
                if FWAppearance.accountExportPasswordRestyled { assertLabelsFit(action) }
                XCTAssertGreaterThanOrEqual(action.bounds.height, 44)
            }
        }
    }

    func testExportPasswordSecureToggleInputAndCallbacks() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let (controller, presenter) = makeController(localization: localization, single: true)
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let fields = try inputFields(controller)
        let action = try actionButton(controller)
        let eyes = descendants(controller.view).compactMap { $0 as? RoundedButton }
            .sorted { $0.convert($0.bounds, to: controller.view).minY < $1.convert($1.bounds, to: controller.view).minY
            }
        XCTAssertEqual(eyes.count, 2)
        XCTAssertEqual(controller.title, R.string.localizable.commonExport(preferredLanguages: ["en"]))
        XCTAssertFalse(action.isEnabled)
        enter("public-fixture", into: fields[0], controller: controller)
        XCTAssertFalse(action.isEnabled)
        enter("public-fixture", into: fields[1], controller: controller)
        XCTAssertTrue(action.isEnabled)
        for (index, eye) in eyes.enumerated() {
            await activate(eye, in: window)
            XCTAssertFalse(fields[index].textField.isSecureTextEntry)
            await reveal(fields[index].textField, in: window)
            XCTAssertTrue(isVisible(fields[index].textField))
            XCTAssertGreaterThan(
                fields[index].textField.textColor?.resolvedColor(with: controller.traitCollection).cgColor.alpha ?? 0,
                0
            )
            capture(window, name: "revealed-public-fixture-\(index)")
            XCTAssertEqual(fields[index].text, "public-fixture")
            await activate(eye, in: window)
            XCTAssertTrue(fields[index].textField.isSecureTextEntry)
            XCTAssertEqual(fields[index].text, "public-fixture")
        }
        await activate(action, in: window)
        XCTAssertEqual(presenter.proceeds, 1)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(fields[1]))
        XCTAssertEqual(presenter.proceeds, 2)
        controller.set(error: .passwordMismatch)
        await settle(window)
        enter("public-fixture-updated", into: fields[0], controller: controller)
        await settle(window)
        XCTAssertFalse(
            descendants(controller.view).compactMap { $0 as? UILabel }
                .contains {
                    $0.text == AccountExportPasswordError.passwordMismatch
                        .toErrorContent(for: localization.selectedLocale)
                        .message
                }
        )
        capture(window, name: "secure-input-and-error-cleared")
    }

    func testExportPasswordLiveLocaleTypeAndKeyboardContinuity() async throws {
        try XCTSkipUnless(FWAppearance.accountExportPasswordRestyled)
        let probe = KeyboardProbe()
        defer { probe.close() }
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let (controller, presenter) = makeController(localization: localization)
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let fields = try inputFields(controller)
        enter("public-fixture", into: fields[0], controller: controller)
        enter("public-fixture", into: fields[1], controller: controller)
        controller.set(error: .passwordMismatch)
        XCTAssertTrue(fields[0].becomeFirstResponder())
        let editor = fields[0].textField!
        let caret = try XCTUnwrap(editor.position(from: editor.beginningOfDocument, offset: 4))
        editor.selectedTextRange = editor.textRange(from: caret, to: caret)
        let oldModels = [presenter.password.inputHandler.value, presenter.confirmation.inputHandler.value]
        localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        controller.applyLocalization()
        await settle(window)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(
            editor.offset(from: editor.beginningOfDocument, to: try XCTUnwrap(editor.selectedTextRange).start),
            4
        )
        XCTAssertEqual(fields.map { $0.text ?? "" }, oldModels)
        XCTAssertEqual(presenter.setups, 1)
        XCTAssertTrue(editor.isSecureTextEntry)
        capture(window, name: "live-ja-AX5-active-editor")
        let locale = localization.selectedLocale
        XCTAssertTrue(
            descendants(controller.view).compactMap { $0 as? UILabel }
                .contains { $0.text == AccountExportPasswordError.passwordMismatch.toErrorContent(for: locale).message
                },
            "Visible mismatch error must follow the live locale"
        )
        XCTAssertEqual(
            fields[0].textFont?.pointSize,
            UIFont.fw(.bodyL, locale: locale, compatibleWith: controller.traitCollection).pointSize
        )
        await settleNativeKeyboard(probe, window: window)
        let keyboard = window.convert(CGRect(x: 0, y: 340, width: 320, height: 228), to: nil)
        controller.updateWhileKeyboardFrameChanging(keyboard)
        await settleKeyboardScroll(editor: editor, window: window, bottom: 340)
        let frame = editor.convert(editor.bounds, to: window)
        capture(window, name: "live-ja-AX5-injected-keyboard")
        XCTAssertGreaterThanOrEqual(frame.minY, controller.view.safeAreaInsets.top)
        XCTAssertLessThanOrEqual(frame.maxY, 340.5)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(editor.text, oldModels[0])
        let action = try actionButton(controller)
        await reveal(action, in: window)
        await settleKeyboardScroll(editor: action, window: window, bottom: 340)
        capture(window, name: "live-ja-AX5-keyboard-action")
        XCTAssertLessThanOrEqual(
            action.convert(action.bounds, to: window).maxY,
            340.5,
            "Continue must be scroll-reachable above the keyboard"
        )
    }

    func testExportPasswordLiveWidthBoldAndConfirmationEditor() async throws {
        try XCTSkipUnless(FWAppearance.accountExportPasswordRestyled)
        let probe = KeyboardProbe()
        defer { probe.close() }
        let localization = try XCTUnwrap(LocalizationManager(localization: "ja"))
        let (controller, presenter) = makeController(localization: localization)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
        await settle(window)
        let fields = try inputFields(controller)
        let sample = String(repeating: "public-fixture-", count: 5)
        fields.forEach { enter(sample, into: $0, controller: controller) }
        let editor = fields[1].textField!
        XCTAssertTrue(fields[1].becomeFirstResponder())
        let position = try XCTUnwrap(editor.position(from: editor.beginningOfDocument, offset: 7))
        editor.selectedTextRange = editor.textRange(from: position, to: position)
        let regular = try XCTUnwrap(fields[1].textFont)
        for width in [CGFloat(640), CGFloat(320)] {
            window.frame.size.width = width
            window.setNeedsLayout()
            await settle(window)
            for field in fields {
                assertLabelsFit(field)
                assertContained(field.textField, in: field)
                XCTAssertGreaterThanOrEqual(field.textField.bounds.height, 44)
            }
            await reveal(fields[1], in: window)
            capture(window, name: "live-confirmation-width-\(Int(width))")
            XCTAssertTrue(editor.isFirstResponder)
            XCTAssertEqual(
                editor.offset(from: editor.beginningOfDocument, to: try XCTUnwrap(editor.selectedTextRange).start),
                7
            )
        }
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .bold }
        await settle(window)
        let bold = try XCTUnwrap(fields[1].textFont)
        XCTAssertGreaterThan(fontWeight(bold), fontWeight(regular))
        XCTAssertEqual(bold.pointSize, regular.pointSize)
        fields.forEach { assertLabelsFit($0); assertContained($0.textField, in: $0) }
        await reveal(fields[1], in: window)
        capture(window, name: "live-confirmation-bold")
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
        await settle(window)
        XCTAssertEqual(fields[1].textFont?.fontName, regular.fontName)
        XCTAssertEqual(fields[1].textFont?.pointSize, regular.pointSize)
        XCTAssertEqual(fields.map { $0.text ?? "" }, [sample, sample])
        XCTAssertTrue(editor.isSecureTextEntry)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(
            editor.offset(from: editor.beginningOfDocument, to: try XCTUnwrap(editor.selectedTextRange).start),
            7
        )
        XCTAssertEqual(presenter.setups, 1)
        controller
            .updateWhileKeyboardFrameChanging(window.convert(CGRect(x: 0, y: 340, width: 320, height: 228), to: nil))
        await settleKeyboardScroll(editor: editor, window: window, bottom: 340)
        let frame = editor.convert(editor.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, controller.view.safeAreaInsets.top)
        XCTAssertLessThanOrEqual(frame.maxY, 340.5)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === editor || hit?.isDescendant(of: editor) == true)
        capture(window, name: "live-confirmation-keyboard-regular")
        let action = try actionButton(controller)
        await activate(action, in: window)
        XCTAssertLessThanOrEqual(action.convert(action.bounds, to: window).maxY, 340.5)
        XCTAssertEqual(presenter.proceeds, 1)
        let eyes = descendants(controller.view).compactMap { $0 as? RoundedButton }
            .sorted { $0.convert($0.bounds, to: controller.view).minY < $1.convert($1.bounds, to: controller.view).minY
            }
        await activate(try XCTUnwrap(eyes.last), in: window)
        XCTAssertFalse(editor.isSecureTextEntry)
        XCTAssertEqual(editor.text, sample)
        await reveal(editor, in: window)
        capture(window, name: "live-confirmation-revealed-public-fixture")
    }

    private func fontWeight(_ font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return (traits?[.weight] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    }

    private final class KeyboardProbe {
        private var tokens: [NSObjectProtocol] = []
        private var pending = false
        private var hasShown = false
        private var latest = Date()
        private(set) var observations: [String] = []

        init() {
            for name in [UIResponder.keyboardWillShowNotification, UIResponder.keyboardDidShowNotification,
                         UIResponder.keyboardWillChangeFrameNotification,
                         UIResponder.keyboardDidChangeFrameNotification,
                         UIResponder.keyboardWillHideNotification, UIResponder.keyboardDidHideNotification] {
                tokens
                    .append(
                        NotificationCenter.default
                            .addObserver(forName: name, object: nil, queue: .main) { [weak self] event in
                                self?.latest = Date()
                                self?.pending = event.name.rawValue.contains("Will")
                                if event.name == UIResponder.keyboardDidShowNotification { self?.hasShown = true }
                                self?.observations
                                    .append(
                                        "time=\(Date().timeIntervalSince1970); name=\(event.name.rawValue); frame=\(String(describing: event.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]))"
                                    )
                            }
                    )
            }
        }

        var isIdle: Bool { hasShown && !pending && Date().timeIntervalSince(latest) >= 0.25 }
        func close() { tokens.forEach { NotificationCenter.default.removeObserver($0) }; tokens = [] }
    }

    private func settleNativeKeyboard(_ probe: KeyboardProbe, window: UIWindow) async {
        for _ in 0 ..< 80 {
            window.layoutIfNeeded()
            if probe.isIdle { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(
            probe.isIdle,
            "Native keyboard notifications must settle before injecting the constrained viewport"
        )
        let attachment = XCTAttachment(string: probe.observations.joined(separator: "\n"))
        attachment.name = "export-password-native-keyboard-notifications"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExportPasswordKeyboardNotificationsRevealAndHide() async throws {
        try XCTSkipUnless(FWAppearance.accountExportPasswordRestyled)
        let probe = KeyboardProbe()
        defer { probe.close() }
        let localization = try XCTUnwrap(LocalizationManager(localization: "ja"))
        let (controller, presenter) = makeController(localization: localization)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        await settle(window)
        let fields = try inputFields(controller)
        let editor = fields[0].textField!
        enter("public-fixture", into: fields[0], controller: controller)
        XCTAssertTrue(fields[0].becomeFirstResponder())
        await settleNativeKeyboard(probe, window: window)
        let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
        let keyboard = window.convert(CGRect(x: 0, y: 340, width: 320, height: 228), to: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: keyboard),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0
        ])
        await settleKeyboardScroll(editor: editor, window: window, bottom: 340)
        XCTAssertEqual(scroll.contentInset.bottom, 228, accuracy: 0.5)
        XCTAssertLessThanOrEqual(editor.convert(editor.bounds, to: window).maxY, 340.5)
        XCTAssertTrue(editor.isFirstResponder)
        XCTAssertEqual(editor.text, "public-fixture")
        XCTAssertTrue(editor.isSecureTextEntry)
        XCTAssertEqual(presenter.setups, 1)
        capture(window, name: "posted-keyboard-show")
        NotificationCenter.default.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: [
            UIResponder
                .keyboardFrameEndUserInfoKey: NSValue(
                    cgRect: window
                        .convert(CGRect(x: 0, y: 300, width: 320, height: 268), to: nil)
                ),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0
        ])
        await settleKeyboardScroll(editor: editor, window: window, bottom: 300)
        XCTAssertEqual(scroll.contentInset.bottom, 268, accuracy: 0.5)
        XCTAssertLessThanOrEqual(editor.convert(editor.bounds, to: window).maxY, 300.5)
        XCTAssertTrue(editor.isFirstResponder)
        capture(window, name: "posted-keyboard-frame-change")
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil, userInfo: [
            UIResponder
                .keyboardFrameEndUserInfoKey: NSValue(
                    cgRect: window
                        .convert(CGRect(x: 0, y: 568, width: 320, height: 228), to: nil)
                ),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0
        ])
        await settle(window)
        XCTAssertEqual(scroll.contentInset.bottom, 0, accuracy: 0.5)
        XCTAssertTrue(editor.isFirstResponder)
        capture(window, name: "posted-keyboard-hide")
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    private func makeController(
        localization: LocalizationManager,
        single: Bool = false
    ) -> (AccountExportPasswordViewController, Presenter) {
        let controller = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = Presenter(single: single)
        presenter.view = controller
        controller.presenter = presenter
        controller.localizationManager = localization
        return (controller, presenter)
    }

    private func inputFields(_ controller: UIViewController) throws -> [AnimatedTextField] {
        let fields = descendants(controller.view).compactMap { $0 as? AnimatedTextField }
            .sorted { $0.convert($0.bounds, to: controller.view).minY < $1.convert($1.bounds, to: controller.view).minY
            }
        XCTAssertEqual(fields.count, 2)
        return fields
    }

    private func actionButton(_ controller: UIViewController) throws -> TriangularedButton {
        try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first)
    }

    private func errorLabel(_ controller: UIViewController, locale: Locale) throws -> UILabel {
        try XCTUnwrap(
            descendants(controller.view).compactMap { $0 as? UILabel }
                .first { $0.text == AccountExportPasswordError.passwordMismatch.toErrorContent(for: locale).message }
        )
    }

    private func enter(
        _ value: String,
        into field: AnimatedTextField,
        controller: AccountExportPasswordViewController
    ) {
        let range = NSRange(location: 0, length: (field.text ?? "").utf16.count)
        if controller
            .animatedTextField(field, shouldChangeCharactersIn: range, replacementString: value) { field.text = value }
        field.sendActions(for: .editingChanged)
    }

    private func assertContained(
        _ child: UIView,
        in parent: UIView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = child.convert(child.bounds, to: parent)
        XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, parent.bounds.width + 0.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, parent.bounds.height + 0.5, file: file, line: line)
    }

    private func assertLabelsFit(_ view: UIView, file: StaticString = #filePath, line: UInt = #line) {
        for label in descendants(view).compactMap({ $0 as? UILabel }).filter({ self.isVisible($0) }) {
            let fit = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(fit.height, label.bounds.height + 0.5, file: file, line: line)
            assertContained(label, in: view, file: file, line: line)
        }
    }

    private func isVisible(_ view: UIView) -> Bool {
        guard !view.isHidden, view.alpha > 0 else { return false }
        return view.superview.map { isVisible($0) } ?? true
    }

    private func settleKeyboardScroll(editor: UIView, window: UIWindow, bottom: CGFloat) async {
        guard let scroll = descendants(window).compactMap({ $0 as? UIScrollView }).first else { return }
        var previous = scroll.contentOffset
        var stable = 0
        var observations: [String] = []
        for tick in 0 ..< 60 {
            window.layoutIfNeeded()
            let frame = editor.convert(editor.bounds, to: window)
            observations
                .append("tick=\(tick); frame=\(frame); offset=\(scroll.contentOffset); inset=\(scroll.contentInset)")
            stable = abs(previous.y - scroll.contentOffset.y) < 0.1 ? stable + 1 : 0
            previous = scroll.contentOffset
            if frame.maxY <= bottom + 0.5, frame.minY >= window.safeAreaInsets.top, stable >= 3 { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        let diagnostic = XCTAttachment(string: observations.joined(separator: "\n"))
        diagnostic.name = "export-password-keyboard-scroll-observations"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }

    private func reveal(_ view: UIView, in window: UIWindow) async {
        var ancestor = view.superview
        while let current = ancestor {
            if let scroll = current as? UIScrollView {
                scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false)
                break
            }
            ancestor = current.superview
        }
        await settle(window)
    }

    private func activate(_ control: UIControl, in window: UIWindow) async {
        await reveal(control, in: window)
        let frame = control.convert(control.bounds, to: window)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(
            hit === control || hit?.isDescendant(of: control) == true,
            "Native control must receive hit testing"
        )
        control.sendActions(for: .touchUpInside)
        await settle(window)
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = FearlessNavigationController(rootViewController: controller)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0 ..< 60 {
            window.layoutIfNeeded()
            if !descendants(window).contains(where: { view in
                (view.layer.animationKeys() ?? [])
                    .contains {
                        $0.hasPrefix("bounds") || $0.hasPrefix("position") || view.layer
                            .animation(forKey: $0) is CATransition
                    }
            }) { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Export presentation animations did not settle")
    }

    private func close(_ window: UIWindow) {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }

    private func capture(_ window: UIWindow, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        })
        attachment.name = "export-password-baseline-" + name
        attachment.lifetime = .keepAlways
        add(attachment)
        let metrics = descendants(window).compactMap { view -> String? in
            guard let label = view as? UILabel else { return nil }
            return "label=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
        }.joined(separator: "\n")
        let diagnostic = XCTAttachment(string: metrics)
        diagnostic.name = "export-password-metrics-" + name
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }
}

@MainActor
final class BackupMarkerDurabilityTests: XCTestCase {
    private enum Failure: Error { case storage }

    private final class Events: EventCenterProtocol {
        private let lock = NSLock()
        private var recorded: [MetaAccountModel] = []
        var wallets: [MetaAccountModel] {
            lock.lock(); defer { lock.unlock() }; return recorded
        }
        func notify(with event: EventProtocol) {
            if let event = event as? MetaAccountModelChangedEvent {
                lock.lock(); recorded.append(event.account); lock.unlock()
            }
        }
        func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
        func remove(observer _: EventVisitorProtocol) {}
    }

    private final class Output: AccountConfirmInteractorOutputProtocol, ExportSeedInteractorOutputProtocol {
        var completed = 0
        var errors: [Error] = []
        var result: ((Result<Void, Error>) -> Void)?
        func didReceive(words _: [String], afterConfirmationFail _: Bool) {}
        func didCompleteConfirmation() { completed += 1; result?(.success(())) }
        func didReceive(error: Error) { errors.append(error); result?(.failure(error)) }
        func didReceive(exportData _: [ExportSeedData], notShown _: [ExportSeedNotShown]) {}
    }

    private final class Storage: CoreDataServiceProtocol {
        let configuration: CoreDataServiceConfigurationProtocol
        let backing: CoreDataServiceProtocol
        private let lock = NSLock()
        private var requests: [CoreDataContextInvocationBlock] = []
        init(backing: CoreDataServiceProtocol) {
            self.backing = backing
            configuration = backing.configuration
        }
        var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
        func performAsync(block: @escaping CoreDataContextInvocationBlock) {
            lock.lock(); requests.append(block); lock.unlock()
        }
        func finish(_ index: Int, failure: Bool = false) {
            lock.lock(); let block = requests[index]; lock.unlock()
            if failure { block(nil, Failure.storage) } else { backing.performAsync(block: block) }
        }
        func close() throws {}
        func drop() throws {}
    }

    private final class Facade: fearless.StorageFacadeProtocol {
        let databaseService: CoreDataServiceProtocol
        init(_ service: CoreDataServiceProtocol) { databaseService = service }
        func createRepository<T, U>(filter: NSPredicate?, sortDescriptors: [NSSortDescriptor], mapper: AnyCoreDataMapper<T, U>) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
            CoreDataRepository(databaseService: databaseService, mapper: mapper, filter: filter, sortDescriptors: sortDescriptors)
        }
        func createAsyncRepository<T, U>(filter: NSPredicate?, sortDescriptors: [NSSortDescriptor], mapper: AnyCoreDataMapper<T, U>) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
            AsyncCoreDataRepositoryDefault(databaseService: databaseService, mapper: mapper, filter: filter, sortDescriptors: sortDescriptors)
        }
    }

    private struct Fixture {
        let wallet: MetaAccountModel
        let source: UserDataStorageTestFacade
        let storage: Storage
        let facade: Facade
        let settings: SelectedWalletSettings
        let queue: OperationQueue
        let events: Events
    }

    private func fixture(wallet suppliedWallet: MetaAccountModel? = nil) async throws -> Fixture {
        let source = UserDataStorageTestFacade()
        let queue = OperationQueue()
        let wallet = suppliedWallet ?? AccountGenerator.generateMetaAccount().replacingIsBackuped(false)
        let saved: Result<MetaAccountModel, Error> = await withCheckedContinuation { continuation in
            SelectedWalletSettings(storageFacade: source, operationQueue: queue)
                .performSave(value: wallet) { continuation.resume(returning: $0) }
        }
        _ = try saved.get()
        let storage = Storage(backing: source.databaseService)
        let facade = Facade(storage)
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: queue)
        settings.applySetupResult(.success(wallet))
        return Fixture(wallet: wallet, source: source, storage: storage, facade: facade, settings: settings, queue: queue, events: Events())
    }

    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0 ..< 200 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Controlled persistence did not reach the expected state")
    }

    private func settle(_ queue: OperationQueue) async {
        await waitUntil { queue.operationCount == 0 }
        try? await Task.sleep(nanoseconds: 30_000_000)
    }

    private func reopened(_ fixture: Fixture) async throws -> MetaAccountModel {
        let result: Result<MetaAccountModel?, Error> = await withCheckedContinuation { continuation in
            SelectedWalletSettings(storageFacade: fixture.source, operationQueue: fixture.queue)
                .setup(runningCompletionIn: nil) { continuation.resume(returning: $0) }
        }
        return try XCTUnwrap(result.get())
    }

    private func failSettingsSave(_ f: Fixture) async {
        await waitUntil { f.storage.count == 1 }
        f.storage.finish(0, failure: true)
        await settle(f.queue)
    }

    func testMnemonicDoesNotPublishOrCompleteBeforeFailedMarkerSave() async throws {
        let f = try await fixture()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let output = Output()
        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic, settings: f.settings, wallet: f.wallet, eventCenter: f.events, recordsWholeWalletBackup: true)
        interactor.presenter = output
        interactor.confirm(words: mnemonic.allWords())
        XCTAssertEqual(output.completed, 0, "Phrase confirmation must wait for durable backup marker")
        XCTAssertTrue(f.events.wallets.isEmpty, "No backed-up event may precede persistence")
        await failSettingsSave(f)
        XCTAssertEqual(output.completed, 0)
        XCTAssertEqual(output.errors.count, 1)
        XCTAssertTrue(f.events.wallets.isEmpty)
        let stored = try await reopened(f)
        XCTAssertFalse(stored.hasBackup)
        interactor.confirm(words: mnemonic.allWords())
        interactor.confirm(words: mnemonic.allWords())
        await succeedSettingsSave(f, startingAt: 1)
        XCTAssertEqual(output.completed, 1)
        XCTAssertEqual(f.events.wallets.count, 1)
        let retried = try await reopened(f)
        XCTAssertTrue(retried.hasBackup)
        interactor.confirm(words: mnemonic.allWords())
        XCTAssertEqual(f.storage.count, 2)
    }

    func testJsonDoesNotPublishBeforeFailedMarkerSave() async throws {
        let f = try await fixture()
        let interactor = ExportRestoreJsonInteractor(settings: f.settings, wallet: f.wallet, eventCenter: f.events)
        var results: [Result<Void, Error>] = []
        interactor.walletDidBackuped { results.append($0) }
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(f.events.wallets.isEmpty, "Successful sharing does not acknowledge local marker persistence")
        await failSettingsSave(f)
        XCTAssertTrue(f.events.wallets.isEmpty)
        let stored = try await reopened(f)
        XCTAssertFalse(stored.hasBackup)
        XCTAssertEqual(results.count, 1)
        if case .success = results.first { XCTFail("Failure must remain retryable") }
        interactor.walletDidBackuped { results.append($0) }
        await succeedSettingsSave(f, startingAt: 1)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(f.events.wallets.count, 1)
        let retried = try await reopened(f)
        XCTAssertTrue(retried.hasBackup)
    }

    func testSeedDoesNotPublishFailedMarkerSaveAsSuccess() async throws {
        let f = try await fixture()
        let output = Output()
        let interactor = ExportSeedInteractor(
            seedReader: VerifiedSeedExportReader(keystore: InMemoryKeychain()),
            backupMarker: f.settings,
            operationManager: OperationManager(operationQueue: f.queue),
            chainRepository: AnyDataProviderRepository(SubstrateStorageTestFacade().createRepository(filter: nil, sortDescriptors: [], mapper: AnyCoreDataMapper(ChainModelMapper()))),
            eventCenter: f.events
        )
        interactor.presenter = output
        interactor.didBackupSeed(wallet: f.wallet) { result in
            if case let .failure(error) = result { output.didReceive(error: error) }
        }
        await waitUntil { f.storage.count == 1 }
        XCTAssertTrue(f.events.wallets.isEmpty)
        f.storage.finish(0, failure: true)
        await settle(f.queue)
        XCTAssertTrue(f.events.wallets.isEmpty, "A failed repository operation must not announce hasBackup=true")
        XCTAssertEqual(output.errors.count, 1)
        let stored = try await reopened(f)
        XCTAssertFalse(stored.hasBackup)
        var retried = false
        interactor.didBackupSeed(wallet: f.wallet) { result in
            if case .success = result { retried = true }
        }
        await waitUntil { f.storage.count == 2 }
        f.storage.finish(1)
        await settle(f.queue)
        XCTAssertTrue(retried)
        XCTAssertEqual(f.events.wallets.count, 1)
        let afterRetry = try await reopened(f)
        XCTAssertTrue(afterRetry.hasBackup)
    }

    private func succeedSettingsSave(_ f: Fixture, startingAt index: Int) async {
        await waitUntil { f.storage.count == index + 1 }
        f.storage.finish(index)
        await settle(f.queue)
    }

    private final class Backup: ExportRestoreJsonInteractorProtocol, ExportSeedInteractorInputProtocol {
        var completions: [(Result<Void, Error>) -> Void] = []
        func walletDidBackuped(completion: @escaping (Result<Void, Error>) -> Void) { completions.append(completion) }
        func didBackupSeed(wallet _: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void) { completions.append(completion) }
        func fetchExportDataForAddress(_: String, chain _: ChainModel, wallet _: MetaAccountModel) {}
        func fetchExportDataForWallet(_: MetaAccountModel, accounts _: [ChainAccountInfo]) {}
    }

    private final class SheetPresenter: SheetAlertPresentable {}

    private final class Wireframe: ExportRestoreJsonWireframeProtocol, ExportSeedWireframeProtocol, AccountConfirmWireframeProtocol {
        var selection: ModalPickerSelectionCallback?
        var shares: [SharingCompletionHandler] = []
        var sheets: [SheetAlertPresentableViewModel] = []
        var errors: [Error] = []
        var proceeded = 0
        var renderSheets = false
        func back(view _: ExportGenericViewProtocol?) {}
        func showChangePassword(from _: ExportGenericViewProtocol?) {}
        func showJsonExport(flow _: ExportFlow, from _: ExportGenericViewProtocol?) {}
        func proceed(from _: AccountConfirmViewProtocol?, flow _: AccountConfirmFlow?) { proceeded += 1 }
        func presentExportActionsFlow(from _: ControllerBackedProtocol?, items _: [JsonExportAction], callback: @escaping ModalPickerSelectionCallback) { selection = callback }
        func share(sources _: [Any], from _: ControllerBackedProtocol?, with handler: SharingCompletionHandler?) { if let handler { shares.append(handler) } }
        func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with handler: SharingCompletionHandler?) { if let handler { shares.append(handler) } }
        func presentBackupStatusFailure(from view: ExportGenericViewProtocol?, locale: Locale, retry: @escaping () -> Void) {
            sheets.append(SheetAlertPresentableViewModel(title: "", message: nil, actions: [SheetAlertPresentableAction(title: R.string.localizable.commonRetry(preferredLanguages: locale.rLanguages), handler: retry)], closeAction: nil))
            if renderSheets { view?.showBackupStatusFailure(retry: retry) }
        }
        func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
            sheets.append(viewModel)
            if renderSheets { SheetPresenter().present(viewModel: viewModel, from: view) }
        }
        func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { errors.append(error); return true }
    }

    private struct ExportFixture {
        let json: ExportRestoreJsonPresenter
        let seed: ExportSeedPresenter
        let backup: Backup
        let wireframe: Wireframe
        let seedText: String
        let seedData: ExportSeedData
        let localization: LocalizationManager
    }

    private func exportFixture(single: Bool = false, locale: String = "en") throws -> ExportFixture {
        let localization = try XCTUnwrap(LocalizationManager(localization: locale))
        let wallet = AccountGenerator.generateMetaAccount().replacingIsBackuped(false)
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        let account = ChainAccountResponse(chainId: chain.chainId, accountId: wallet.substrateAccountId!, publicKey: wallet.substratePublicKey!, name: "Public marker fixture", cryptoType: .sr25519, addressPrefix: chain.addressPrefix, isEthereumBased: false, isChainAccount: false, walletId: wallet.metaId)
        let info = ChainAccountInfo(chain: chain, account: account)
        let flow: ExportFlow = single ? .single(chain: chain, address: "public-fixture", wallet: wallet) : .multiple(wallet: wallet, accounts: [info])
        let model = RestoreJson(data: "public encrypted fixture", chain: chain, cryptoType: .sr25519, fileURL: URL(fileURLWithPath: "/tmp/public-marker.json"), accountId: account.accountId)
        let json = ExportRestoreJsonPresenter(models: [model], flow: flow, localizationManager: localization)
        let seed = ExportSeedPresenter(flow: flow, localizationManager: localization)
        let backup = Backup()
        let wireframe = Wireframe()
        json.interacror = backup; json.wireframe = wireframe
        seed.interactor = backup; seed.wireframe = wireframe
        let seedData = Data(repeating: 0x41, count: 32)
        let exportData = ExportSeedData(seed: seedData, derivationPath: nil, chain: chain, cryptoType: .sr25519)
        seed.didReceive(exportData: [exportData], notShown: [])
        return ExportFixture(json: json, seed: seed, backup: backup, wireframe: wireframe, seedText: seedData.toHex(includePrefix: true), seedData: exportData, localization: localization)
    }

    private func share(_ fixture: ExportFixture, json: Bool) throws {
        if json {
            fixture.json.didTapExportSubstrateButton()
            try XCTUnwrap(fixture.wireframe.selection)(0)
        } else {
            fixture.seed.share(fixture.seedText)
        }
        try XCTUnwrap(fixture.wireframe.shares.last)(true)
    }

    func testJsonAndSeedRetryMarkerWithoutRepeatingShareAndIgnoreDuplicateReplies() throws {
        for json in [true, false] {
            let f = try exportFixture()
            try share(f, json: json)
            XCTAssertEqual(f.backup.completions.count, 1)
            f.wireframe.shares[0](true)
            XCTAssertEqual(f.backup.completions.count, 1)
            f.backup.completions[0](.failure(Failure.storage))
            XCTAssertEqual(f.wireframe.sheets.count, 1)
            f.backup.completions[0](.success(()))
            try XCTUnwrap(f.wireframe.sheets[0].actions.first?.handler)()
            XCTAssertEqual(f.backup.completions.count, 2)
            XCTAssertEqual(f.wireframe.shares.count, 1, "Marker retry must not export sensitive data again")
            f.backup.completions[1](.success(()))
            f.backup.completions[1](.failure(Failure.storage))
            try share(f, json: json)
            XCTAssertEqual(f.backup.completions.count, 2, "Acknowledged marker is terminal")
            XCTAssertEqual(f.wireframe.sheets.count, 1)
        }
    }

    func testDuplicateShareRepliesCannotRetryAFailedMarker() throws {
        for json in [true, false] {
            let f = try exportFixture()
            try share(f, json: json)
            f.backup.completions[0](.failure(Failure.storage))
            f.wireframe.shares[0](true)
            XCTAssertEqual(f.backup.completions.count, 1, "A duplicate share completion cannot perform the user's marker retry")
            let cancelled = try exportFixture()
            if json {
                cancelled.json.didTapExportSubstrateButton()
                try XCTUnwrap(cancelled.wireframe.selection)(0)
            } else { cancelled.seed.share(cancelled.seedText) }
            cancelled.wireframe.shares[0](false)
            cancelled.wireframe.shares[0](true)
            XCTAssertTrue(cancelled.backup.completions.isEmpty, "A cancelled share cannot later claim success")
        }
    }

    func testJsonAndSeedLeavingFencesLateShareAndMarkerFailures() throws {
        for json in [true, false] {
            let f = try exportFixture()
            try share(f, json: json)
            if json { f.json.didLeaveView() } else { f.seed.didLeaveView() }
            f.backup.completions[0](.failure(Failure.storage))
            f.wireframe.shares[0](true)
            XCTAssertTrue(f.wireframe.sheets.isEmpty)
            XCTAssertEqual(f.backup.completions.count, 1)
        }
    }

    func testSingleAccountSeedShareDoesNotMarkWholeWalletBackedUp() throws {
        let f = try exportFixture(single: true)
        try share(f, json: false)
        XCTAssertTrue(f.backup.completions.isEmpty)
    }

    func testAbandonedMnemonicPresenterDoesNotNavigateAfterAcknowledgedWrite() async throws {
        let f = try await fixture()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic, settings: f.settings, wallet: f.wallet, eventCenter: f.events, recordsWholeWalletBackup: true)
        let wireframe = Wireframe()
        let presenter = AccountConfirmPresenter(interactor: interactor, wireframe: wireframe, localizationManager: LocalizationManager.shared)
        interactor.presenter = presenter
        presenter.confirm(words: mnemonic.allWords())
        presenter.didLeaveView()
        presenter.confirm(words: mnemonic.allWords())
        await succeedSettingsSave(f, startingAt: 0)
        XCTAssertEqual(wireframe.proceeded, 0)
        XCTAssertEqual(f.events.wallets.count, 1, "Abandonment cannot undo an acknowledged issued write")
        let stored = try await reopened(f)
        XCTAssertTrue(stored.hasBackup)
    }

    func testUnverifiedMnemonicConfirmationDoesNotMarkWholeWallet() async throws {
        let f = try await fixture()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic, settings: f.settings, wallet: f.wallet, eventCenter: f.events, recordsWholeWalletBackup: false)
        let output = Output(); interactor.presenter = output
        interactor.confirm(words: mnemonic.allWords())
        await settle(f.queue)
        XCTAssertEqual(f.storage.count, 0)
        XCTAssertEqual(output.completed, 1)
        XCTAssertTrue(f.events.wallets.isEmpty, "Word confirmation without verified account coverage is not a whole-wallet backup")
        let stored = try await reopened(f)
        XCTAssertFalse(stored.hasBackup)
    }

    private func storedRecords(_ f: Fixture) async throws -> [MetaAccountSelectionModel] {
        let repository = f.source.createRepository(mapper: AnyCoreDataMapper(MetaAccountSelectionMapper()))
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions(includesProperties: true, includesSubentities: true))
        f.queue.addOperations([operation], waitUntilFinished: false)
        await settle(f.queue)
        return try XCTUnwrap(operation.result).get()
    }

    private func mutate(_ f: Fixture, change: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let result: Result<Void, Error> = await withCheckedContinuation { continuation in
            f.source.databaseService.performAsync { context, error in
                continuation.resume(returning: Result {
                    if let error { throw error }
                    guard let context else { throw Failure.storage }
                    try change(context)
                    try context.save()
                })
            }
        }
        try result.get()
    }

    private func startMarker(_ f: Fixture, flow: Int, completion: @escaping (Result<Void, Error>) -> Void) throws -> [AnyObject] {
        if flow == 0 {
            let interactor = ExportRestoreJsonInteractor(settings: f.settings, wallet: f.wallet, eventCenter: f.events)
            interactor.walletDidBackuped(completion: completion)
            return [interactor]
        }
        if flow == 1 {
            let interactor = ExportSeedInteractor(seedReader: VerifiedSeedExportReader(keystore: InMemoryKeychain()), backupMarker: f.settings, operationManager: OperationManager(operationQueue: f.queue), chainRepository: AnyDataProviderRepository(SubstrateStorageTestFacade().createRepository(filter: nil, sortDescriptors: [], mapper: AnyCoreDataMapper(ChainModelMapper()))), eventCenter: f.events)
            interactor.didBackupSeed(wallet: f.wallet, completion: completion)
            return [interactor]
        }
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic, settings: f.settings, wallet: f.wallet, eventCenter: f.events, recordsWholeWalletBackup: true)
        let output = Output(); output.result = completion; interactor.presenter = output
        interactor.confirm(words: mnemonic.allWords())
        return [interactor, output]
    }

    func testDelayedMarkersPreserveNewerWalletNameAndSelection() async throws {
        for flow in 0 ... 2 {
            let f = try await fixture()
            var result: Result<Void, Error>?
            let owners = try startMarker(f, flow: flow) { result = $0 }
            await waitUntil { f.storage.count == 1 }
            let other = AccountGenerator.generateMetaAccount()
            let saved: Result<MetaAccountModel, Error> = await withCheckedContinuation { continuation in
                SelectedWalletSettings(storageFacade: f.source, operationQueue: OperationQueue())
                    .performSave(value: other) { continuation.resume(returning: $0) }
            }
            _ = try saved.get()
            f.settings.applySetupResult(.success(other))
            try await mutate(f) { context in
                let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                request.predicate = NSPredicate(format: "metaId == %@", f.wallet.metaId)
                try XCTUnwrap(context.fetch(request).first).name = "Renamed during export"
            }
            await succeedSettingsSave(f, startingAt: 0)
            if case .failure = result { XCTFail("A display edit does not invalidate the exported key inventory") }
            let records = try await storedRecords(f)
            XCTAssertEqual(records.first(where: { $0.isSelected })?.identifier, other.metaId)
            XCTAssertEqual(records.first(where: { $0.identifier == f.wallet.metaId })?.wallet?.name, "Renamed during export")
            XCTAssertEqual(f.events.wallets.last?.name, "Renamed during export")
            XCTAssertEqual(f.settings.value?.metaId, other.metaId)
            withExtendedLifetime(owners) {}
        }
    }

    func testDelayedMarkersDoNotRestoreDeletedWallet() async throws {
        for flow in 0 ... 2 {
            let f = try await fixture()
            var result: Result<Void, Error>?
            let owners = try startMarker(f, flow: flow) { result = $0 }
            await waitUntil { f.storage.count == 1 }
            try await mutate(f) { context in
                let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                request.predicate = NSPredicate(format: "metaId == %@", f.wallet.metaId)
                for row in try context.fetch(request) { context.delete(row) }
            }
            await succeedSettingsSave(f, startingAt: 0)
            if case .success = result { XCTFail("Deleted export owner must not be recreated") }
            XCTAssertTrue(f.events.wallets.isEmpty)
            let records = try await storedRecords(f)
            XCTAssertTrue(records.isEmpty)
            withExtendedLifetime(owners) {}
        }
    }

    func testDelayedMarkersRejectChangedExportInventory() async throws {
        for flow in 0 ... 2 {
            let f = try await fixture()
            var result: Result<Void, Error>?
            let owners = try startMarker(f, flow: flow) { result = $0 }
            await waitUntil { f.storage.count == 1 }
            let newer = AccountGenerator.generateMetaAccount()
            try await mutate(f) { context in
                let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                request.predicate = NSPredicate(format: "metaId == %@", f.wallet.metaId)
                let row = try XCTUnwrap(context.fetch(request).first)
                row.substrateAccountId = newer.substrateAccountId?.toHex()
                row.substratePublicKey = newer.substratePublicKey
            }
            await succeedSettingsSave(f, startingAt: 0)
            if case .success = result { XCTFail("Old exports do not cover replacement keys") }
            XCTAssertTrue(f.events.wallets.isEmpty)
            let records = try await storedRecords(f)
            XCTAssertEqual(records.first?.wallet?.substratePublicKey, newer.substratePublicKey)
            XCTAssertEqual(records.first?.wallet?.hasBackup, false)
            withExtendedLifetime(owners) {}
        }
    }

    func testMarkerAcknowledgementPreservesNewerSelectedCacheMetadata() async throws {
        let f = try await fixture()
        var result: Result<Void, Error>?
        f.settings.recordBackup(of: f.wallet) { result = $0.map { _ in () } }
        await waitUntil { f.storage.count == 1 }
        let renamed = f.wallet.replacingName("Current cache name")
        f.settings.applySetupResult(.success(renamed))
        try await mutate(f) { context in
            let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
            try XCTUnwrap(context.fetch(request).first).name = renamed.name
        }
        await succeedSettingsSave(f, startingAt: 0)
        XCTAssertNotNil(result)
        XCTAssertEqual(f.settings.value?.name, renamed.name)
        XCTAssertEqual(f.settings.value?.hasBackup, true)
        let stored = try await reopened(f)
        XCTAssertEqual(stored.name, renamed.name)
        XCTAssertTrue(stored.hasBackup)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }

    private func host(_ controller: UIViewController) async throws -> (UIWindow, FearlessNavigationController) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.pushViewController(controller, animated: false)
        try? await Task.sleep(nanoseconds: 550_000_000)
        window.layoutIfNeeded()
        return (window, navigation)
    }

    private func exportController(_ f: ExportFixture, json: Bool) -> ExportGenericViewController {
        let uiFactory = UIFactory()
        let controller = ExportGenericViewController(uiFactory: uiFactory, binder: ExportGenericViewModelBinder(uiFactory: uiFactory), mainTitle: nil, accessoryTitle: nil)
        controller.localizationManager = f.localization
        if json { controller.presenter = f.json; f.json.view = controller }
        else { controller.presenter = f.seed; f.seed.view = controller }
        return controller
    }

    private func activate(_ control: UIControl, in window: UIWindow) async {
        var parent = control.superview
        while let current = parent {
            if let scroll = current as? UIScrollView {
                scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false)
                break
            }
            parent = current.superview
        }
        window.layoutIfNeeded()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let frame = control.convert(control.bounds, to: window)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(control.isEnabled)
        if !(hit === control || hit?.isDescendant(of: control) == true) {
            let attachment = XCTAttachment(string: "control=\(control) frame=\(frame) window=\(window.bounds) hit=\(String(describing: hit))")
            attachment.name = "backup-control-missed-hit-diagnostic"; attachment.lifetime = .keepAlways; add(attachment)
            capture(window, name: "backup-control-missed-hit")
        }
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, "Actual backup control is not reachable: frame=\(frame), window=\(window.bounds), hit=\(String(describing: hit))")
        control.sendActions(for: .touchUpInside)
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    private func capture(_ window: UIWindow, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) })
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testActualJsonAndSeedRetryControlsInAllLocales() async throws {
        for locale in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for json in [true, false] {
                let f = try exportFixture(locale: locale)
                let controller = exportController(f, json: json)
                let (window, _) = try await host(controller)
                defer { window.isHidden = true; window.rootViewController = nil }
                if !json {
                    f.wireframe.sheets.first?.dismissCompletion?()
                    f.seed.didReceive(exportData: [f.seedData], notShown: [])
                    f.wireframe.sheets.removeAll()
                }
                if json {
                    let title = R.string.localizable.exportSubstrateTitle(preferredLanguages: [locale])
                    let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
                    await activate(button, in: window)
                    try XCTUnwrap(f.wireframe.selection)(0)
                    try XCTUnwrap(f.wireframe.shares.last)(true)
                } else { try share(f, json: false) }
                XCTAssertEqual(f.backup.completions.count, 1)
                f.wireframe.renderSheets = true
                f.backup.completions[0](.failure(Failure.storage))
                try? await Task.sleep(nanoseconds: 500_000_000)
                window.layoutIfNeeded()
                XCTAssertNil(controller.presentedViewController)
                let retry = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "BackupStatusRetry" } as? UIControl)
                let message = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "BackupStatusFailure" } as? UILabel)
                let fullText = UILabel()
                fullText.text = message.text
                fullText.font = message.font
                fullText.numberOfLines = 0
                fullText.lineBreakMode = .byWordWrapping
                let required = fullText.sizeThatFits(CGSize(width: message.bounds.width, height: .greatestFiniteMagnitude))
                XCTAssertGreaterThanOrEqual(message.bounds.height + 1, required.height, "Full localized error must fit without truncation: \(locale), allocated=\(message.bounds), required=\(required)")
                let messageFrame = message.convert(message.bounds, to: window)
                XCTAssertGreaterThanOrEqual(messageFrame.minY, controller.view.safeAreaInsets.top - 1, "The failure begins inside the readable viewport")
                XCTAssertLessThan(messageFrame.minY, window.bounds.maxY - message.font.lineHeight, "The first error line is visible")
                capture(window, name: "backup-marker-failure-\(json ? "json" : "seed")-\(locale)")
                if let scroll = descendants(controller.view).compactMap({ $0 as? UIScrollView }).first {
                    scroll.scrollRectToVisible(retry.convert(retry.bounds, to: scroll), animated: false)
                    window.layoutIfNeeded()
                }
                capture(window, name: "backup-marker-actions-\(json ? "json" : "seed")-\(locale)")
                await activate(retry, in: window)
                XCTAssertEqual(f.backup.completions.count, 2)
                XCTAssertEqual(f.wireframe.shares.count, 1)
                f.backup.completions[1](.success(()))
                capture(window, name: "backup-marker-retry-\(json ? "json" : "seed")-\(locale)")
            }
        }
    }

    func testActualBackupCancelLeavesFailedMarkerRetryableWithoutExportingAgain() async throws {
        for json in [true, false] {
            let f = try exportFixture()
            let controller = exportController(f, json: json)
            let (window, _) = try await host(controller)
            defer { window.isHidden = true; window.rootViewController = nil }
            if !json {
                f.wireframe.sheets.first?.dismissCompletion?()
                f.wireframe.sheets.removeAll()
            }
            try share(f, json: json)
            f.wireframe.renderSheets = true
            f.backup.completions[0](.failure(Failure.storage))
            let cancel = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "BackupStatusCancel" } as? UIControl)
            await activate(cancel, in: window)
            XCTAssertFalse(descendants(controller.view).contains { $0.accessibilityIdentifier == "BackupStatusFailure" })
            XCTAssertEqual(f.backup.completions.count, 1)
            XCTAssertEqual(f.wireframe.shares.count, 1)
            f.backup.completions[0](.success(()))
            XCTAssertEqual(f.backup.completions.count, 1)
        }
    }

    func testActualExportPopFencesLateMarkerFailure() async throws {
        for json in [true, false] {
            let f = try exportFixture()
            let controller = exportController(f, json: json)
            let (window, navigation) = try await host(controller)
            defer { window.isHidden = true; window.rootViewController = nil }
            if !json {
                f.wireframe.sheets.first?.dismissCompletion?()
                f.wireframe.sheets.removeAll()
            }
            try share(f, json: json)
            XCTAssertEqual(f.backup.completions.count, 1)
            navigation.popViewController(animated: false)
            try? await Task.sleep(nanoseconds: 100_000_000)
            f.backup.completions[0](.failure(Failure.storage))
            f.wireframe.shares[0](true)
            XCTAssertTrue(f.wireframe.sheets.isEmpty)
            XCTAssertEqual(f.backup.completions.count, 1)
            XCTAssertEqual(navigation.viewControllers.count, 1)
        }
    }

    func testVerifiedMnemonicFactoryControlsWaitForDurableMarker() async throws {
        let keys = InMemoryKeychain()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "legal winner thank year wave sausage worth useful legal winner thank yellow")
        let request = MetaAccountImportMnemonicRequest(mnemonic: mnemonic, username: "Verified public fixture",
            substrateDerivationPath: "//Fixture", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519, defaultChainId: nil)
        let operation = MetaAccountOperationFactory(keystore: keys).newMetaAccountOperation(request: request, isBackuped: false)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let f = try await fixture(wallet: wallet)
        let chains = [ChainAccountRecordsFixture.chain(id: "proof-substrate"),
                      ChainAccountRecordsFixture.chain(id: "proof-ethereum", ethereumBased: true),
                      UniversalWalletRegistry.bitcoinMainnetChainModel, UniversalWalletRegistry.tairaChainModel,
                      UniversalWalletRegistry.solanaMainnetChainModel]
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        let exports = try chains.map { chain in
            try reader.fetch(wallet: wallet, info: ChainAccountInfo(chain: chain, account: XCTUnwrap(wallet.fetch(for: chain.accountRequest()))))
        }
        let proof = try XCTUnwrap(reader.backupProof(wallet: wallet, exports: exports))
        let view = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            mnemonic, wallet: wallet, backupProof: proof, settings: f.settings, eventCenter: f.events
        ))
        let controller = try XCTUnwrap(view.controller as? AccountConfirmViewController)
        let presenter = try XCTUnwrap(controller.presenter as? AccountConfirmPresenter)
        let wireframe = Wireframe(); presenter.wireframe = wireframe
        let (window, _) = try await host(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        var selectedButtons: Set<ObjectIdentifier> = []
        for word in mnemonic.allWords() {
            let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? RoundedButton }.first {
                $0.imageWithTitleView?.title == word && !selectedButtons.contains(ObjectIdentifier($0))
            })
            await activate(button, in: window)
            selectedButtons.insert(ObjectIdentifier(button))
        }
        let title = R.string.localizable.commonConfirm(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
        await activate(button, in: window)
        await waitUntil { f.storage.count == 1 }
        guard f.storage.count == 1 else { throw Failure.storage }
        XCTAssertEqual(wireframe.proceeded, 0)
        XCTAssertTrue(f.events.wallets.isEmpty)
        capture(window, name: "mnemonic-ownership-verified-marker-held")
        await failSettingsSave(f)
        XCTAssertEqual(wireframe.proceeded, 0)
        let failedWallet = try await reopened(f)
        XCTAssertFalse(failedWallet.hasBackup)
        await activate(button, in: window)
        await waitUntil { f.storage.count == 2 }
        guard f.storage.count == 2 else { throw Failure.storage }
        await succeedSettingsSave(f, startingAt: 1)
        XCTAssertEqual(wireframe.proceeded, 1)
        XCTAssertEqual(f.events.wallets.count, 1)
        let acknowledgedWallet = try await reopened(f)
        XCTAssertTrue(acknowledgedWallet.hasBackup)
        capture(window, name: "mnemonic-ownership-verified-marker-acknowledged")
    }

    func testHistoricalTonExactControlsWaitForDurableMarkerAndRetry() async throws {
        // IC07 historical iOS 4.0.4 public identity; exact original significant spaces.
        let phrase = "cluster notice abandon  frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"
        let keys = InMemoryKeychain()
        let native = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(TonSwift.Address.parse("UQDvaKHy6izOBPGdot4wtkje_R2PF_RQl86qPA3e4p3-P84h")),
            publicKey: Data(hexStringSSF: "2d4279cae4f717c80f4b56f4d67b6c189d5fcd260a2a75673c8014fd41da2ea3"), contractVersion: "v4R2")
        let wallet = MetaAccountModel(metaId: "public-ton-confirm-marker", name: "Public TON marker", substrateAccountId: nil,
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: "-239", assetsVisibility: [],
            hasBackup: false, favouriteChainIds: [], legacyTonAccount: native)
        let tag = fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        try keys.saveKey(Data(phrase.utf8), with: tag)
        let f = try await fixture(wallet: wallet)
        let chain = ChainAccountRecordsFixture.chain(id: "-239")
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        let exported = try reader.fetch(wallet: wallet, info: ChainAccountInfo(chain: chain,
            account: XCTUnwrap(wallet.fetch(for: chain.accountRequest()))))
        let mnemonic = exported.mnemonic
        let proof = try XCTUnwrap(reader.backupProof(wallet: wallet, exports: [exported]))
        let view = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            mnemonic, wallet: wallet, backupProof: proof, settings: f.settings, eventCenter: f.events
        ))
        let controller = try XCTUnwrap(view.controller as? AccountConfirmViewController)
        let presenter = try XCTUnwrap(controller.presenter as? AccountConfirmPresenter)
        let wireframe = Wireframe(); presenter.wireframe = wireframe
        let (window, _) = try await host(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        var selectedButtons: Set<ObjectIdentifier> = []
        for word in mnemonic.allWords() {
            let visibleTitle = word.isEmpty ? "[" + R.string.localizable.confirmationExactEmpty(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages) + "]" : word
            let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? RoundedButton }.first {
                $0.imageWithTitleView?.title == visibleTitle && !selectedButtons.contains(ObjectIdentifier($0))
            })
            await activate(button, in: window)
            selectedButtons.insert(ObjectIdentifier(button))
        }
        let title = R.string.localizable.commonConfirm(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
        await activate(button, in: window)
        await waitUntil { f.storage.count == 1 }
        guard f.storage.count == 1 else { throw Failure.storage }
        XCTAssertEqual(wireframe.proceeded, 0)
        XCTAssertTrue(f.events.wallets.isEmpty)
        capture(window, name: "ton-exact-confirm-verified-marker-held")
        await failSettingsSave(f)
        XCTAssertEqual(wireframe.proceeded, 0)
        let failedWallet = try await reopened(f)
        XCTAssertFalse(failedWallet.hasBackup)
        await activate(button, in: window)
        await waitUntil { f.storage.count == 2 }
        guard f.storage.count == 2 else { throw Failure.storage }
        await succeedSettingsSave(f, startingAt: 1)
        XCTAssertEqual(wireframe.proceeded, 1)
        XCTAssertEqual(f.events.wallets.count, 1)
        let acknowledgedWallet = try await reopened(f)
        XCTAssertTrue(acknowledgedWallet.hasBackup)
        XCTAssertEqual(try keys.fetchKey(for: tag), Data(phrase.utf8))
        XCTAssertEqual(acknowledgedWallet.legacyTonAccount, wallet.legacyTonAccount)
        capture(window, name: "ton-exact-confirm-verified-marker-acknowledged")
    }

    func testMnemonicWordControlsStayInsideActualViewport() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: false, checkViewport: true)
    }

    func testActualMnemonicControlsAndPopFenceAcknowledgedCompletion() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: false)
    }

    func testActualAnimatedMnemonicPopFencesAcknowledgedCompletion() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: true)
    }

    func testCancelledInteractiveMnemonicPopResumesAcknowledgedCompletion() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: true, cancelInteractive: true)
    }

    func testCompletedInteractiveMnemonicPopDiscardsAcknowledgedCompletion() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: true, cancelInteractive: false)
    }

    func testCancelledInteractiveMnemonicPopRestoresStorageFailureRetry() async throws {
        try await exerciseMnemonicPopAcknowledgement(animated: true, cancelInteractive: true, failDuringTransition: true)
    }

    private final class InteractivePopDriver: NSObject, UINavigationControllerDelegate, UIViewControllerAnimatedTransitioning {
        let interaction = UIPercentDrivenInteractiveTransition()
        private(set) var started = false
        private(set) var isInteractive = false
        private(set) var completed = false

        func navigationController(_: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
            from _: UIViewController, to _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            operation == .pop ? self : nil
        }
        func navigationController(_: UINavigationController, interactionControllerFor _: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? { interaction }
        func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval { 0.5 }
        func animateTransition(using context: UIViewControllerContextTransitioning) {
            guard let from = context.view(forKey: .from), let to = context.view(forKey: .to) else {
                XCTFail("Actual navigation transition views are required")
                context.completeTransition(false)
                return
            }
            context.containerView.insertSubview(to, belowSubview: from)
            to.frame = context.containerView.bounds
            isInteractive = context.isInteractive
            started = true
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear) {
                from.transform = CGAffineTransform(translationX: context.containerView.bounds.width, y: 0)
            } completion: { _ in
                from.transform = .identity
                if context.transitionWasCancelled { to.removeFromSuperview() }
                context.completeTransition(!context.transitionWasCancelled)
                self.completed = true
            }
        }
    }

    private func exerciseMnemonicPopAcknowledgement(animated: Bool, cancelInteractive: Bool? = nil, failDuringTransition: Bool = false, checkViewport: Bool = false) async throws {
        let f = try await fixture()
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: "bottom drive obey lake curtain smoke basket hold race lonely fit walk")
        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic, settings: f.settings, wallet: f.wallet, eventCenter: f.events, recordsWholeWalletBackup: true)
        let wireframe = Wireframe()
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = AccountConfirmPresenter(interactor: interactor, wireframe: wireframe, localizationManager: localization)
        interactor.presenter = presenter
        let controller = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        controller.presenter = presenter; controller.localizationManager = localization
        let (window, navigation) = try await host(controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        if checkViewport {
            for width in [CGFloat(320), 390, 320] {
                window.frame.size.width = width
                window.setNeedsLayout(); window.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 100_000_000)
                let words = descendants(controller.view).compactMap { $0 as? RoundedButton }.filter { mnemonic.allWords().contains($0.imageWithTitleView?.title ?? "") }
                XCTAssertEqual(words.count, 12)
                for word in words {
                    let frame = word.convert(word.bounds, to: window)
                    XCTAssertGreaterThanOrEqual(frame.minX, 0, "Word must start inside actual viewport: \(frame), viewport=\(window.bounds)")
                    XCTAssertLessThanOrEqual(frame.maxX, window.bounds.maxX, "Complete word control must fit actual viewport: \(frame), viewport=\(window.bounds)")
                }
                capture(window, name: "mnemonic-actual-viewport-word-rows-\(Int(width))")
            }
            return
        }
        for word in mnemonic.allWords() {
            let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? RoundedButton }.first { $0.imageWithTitleView?.title == word })
            await activate(button, in: window)
        }
        let title = R.string.localizable.commonContinue(preferredLanguages: ["en"])
        let button = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
        await activate(button, in: window)
        await waitUntil { f.storage.count == 1 }
        XCTAssertEqual(wireframe.proceeded, 0)
        capture(window, name: "backup-marker-mnemonic-pending-before-pop")
        let interactive = cancelInteractive.map { _ in InteractivePopDriver() }
        if let interactive { navigation.delegate = interactive }
        XCTAssertTrue(navigation.popViewController(animated: animated) === controller)
        if let interactive {
            await waitUntil { interactive.started }
            XCTAssertTrue(interactive.isInteractive, "The actual UIKit transition must be interactive")
            interactive.interaction.update(0.35)
        }
        if failDuringTransition { await failSettingsSave(f) } else { await succeedSettingsSave(f, startingAt: 0) }
        if let interactive, let cancelInteractive {
            XCTAssertTrue(wireframe.errors.isEmpty, "An unresolved departure cannot present an error")
            XCTAssertEqual(wireframe.proceeded, 0, "An unresolved departure cannot navigate after persistence")
            if cancelInteractive { interactive.interaction.cancel() } else { interactive.interaction.finish() }
            await waitUntil { interactive.completed }
            XCTAssertEqual(wireframe.proceeded, cancelInteractive && !failDuringTransition ? 1 : 0)
            XCTAssertEqual(navigation.viewControllers.count, cancelInteractive ? 2 : 1)
            XCTAssertEqual(controller.parent === navigation, cancelInteractive)
            capture(window, name: "mnemonic-owned-interactive-\(cancelInteractive ? "cancel" : "finish")")
            if failDuringTransition {
                XCTAssertTrue(cancelInteractive)
                XCTAssertEqual(wireframe.errors.count, 1)
                XCTAssertTrue(f.events.wallets.isEmpty)
                let failedWallet = try await reopened(f)
                XCTAssertFalse(failedWallet.hasBackup)
                await activate(button, in: window)
                await waitUntil { f.storage.count == 2 }
                await succeedSettingsSave(f, startingAt: 1)
                XCTAssertEqual(wireframe.proceeded, 1)
            }
        } else {
            await waitUntil { controller.parent == nil }
            XCTAssertEqual(wireframe.proceeded, 0)
            XCTAssertEqual(navigation.viewControllers.count, 1)
        }
        XCTAssertEqual(f.events.wallets.count, 1)
        let stored = try await reopened(f)
        XCTAssertTrue(stored.hasBackup)
    }
}

@MainActor
final class AccountExportPasswordLifecycleTests: XCTestCase {
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }

    func testActualFactoryPresentsInitialWarningAfterNavigationAttachment() async throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let view = try XCTUnwrap(AccountExportPasswordViewFactory.createView(flow: .multiple(wallet: wallet, accounts: [])))
        let controller = try XCTUnwrap(view.controller as? AccountExportPasswordViewController)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        navigation.pushViewController(controller, animated: true)
        for _ in 0..<100 where controller.presentedViewController?.view.window == nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        window.layoutIfNeeded()
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = "json-warning-production-initial-presentation"; attachment.lifetime = .keepAlways; add(attachment)
        let sheet = try XCTUnwrap(controller.presentedViewController as? SheetAletViewController,
            "Actual factory warning must appear only after the password controller is attached")
        XCTAssertTrue(sheet.view.window === window)
        let locale = LocalizationManager.shared.selectedLocale
        let proceed = R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages)
        let cancel = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        let controls = descendants(sheet.view).compactMap { $0 as? TriangularedButton }
        XCTAssertEqual(controls.filter { $0.imageWithTitleView?.title == proceed }.count, 1)
        XCTAssertEqual(controls.filter { $0.imageWithTitleView?.title == cancel }.count, 1)
        await waitUntil { !sheet.isBeingPresented && sheet.transitionCoordinator == nil }
        capture(window, name: "json-warning-attached-before-cancel")
        try await activate(try XCTUnwrap(controls.first { $0.imageWithTitleView?.title == cancel }), in: window)
        await waitUntil { navigation.viewControllers.count == 1 && navigation.presentedViewController == nil }
    }
    private final class Exporter: KeystoreExportWrapperProtocol {
        var requests = 0
        var fail = false
        func export(chainAccount _: ChainAccountResponse, password _: String?, address _: String,
                    metaId _: String, accountId _: AccountId?, genesisHash _: String?) throws -> Data {
            requests += 1
            if fail { throw AccountExportPasswordInteractorError.invalidResult }
            return Data("{\"publicFixture\":true}".utf8)
        }
    }

    private final class Wireframe: AccountExportPasswordWireframeProtocol {
        let real = AccountExportPasswordWireframe()
        var exported = 0
        func showJSONExport(_ jsons: [RestoreJson], flow: ExportFlow, from view: AccountExportPasswordViewProtocol?) {
            exported += 1
            real.showJSONExport(jsons, flow: flow, from: view)
        }
        func back(from view: ControllerBackedProtocol?) { real.back(from: view) }
    }

    private struct Fixture {
        let window: UIWindow
        let navigation: FearlessNavigationController
        let controller: AccountExportPasswordViewController
        let presenter: AccountExportPasswordPresenter
        let exporter: Exporter
        let wireframe: Wireframe
        let directory: URL
        let action: TriangularedButton
    }

    private func readyFixture() async throws -> Fixture {
        let wallet = AccountGenerator.generateMetaAccount()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        let info = ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        let view = try XCTUnwrap(AccountExportPasswordViewFactory.createView(flow: .multiple(wallet: wallet, accounts: [info])))
        let controller = try XCTUnwrap(view.controller as? AccountExportPasswordViewController)
        let presenter = try XCTUnwrap(controller.presenter as? AccountExportPasswordPresenter)
        let exporter = Exporter(); let wireframe = Wireframe()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("public-json-lifecycle-" + UUID().uuidString)
        let interactor = AccountExportPasswordInteractor(exportJsonWrapper: exporter,
            accountRepository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())),
            operationManager: OperationManager(operationQueue: OperationQueue()), extrinsicOperationFactory: nil,
            chainRepository: AnyDataProviderRepository(ChainRepositoryFactory().createRepository(sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix])), exportDirectory: directory)
        presenter.interactor = interactor; presenter.wireframe = wireframe; interactor.presenter = presenter
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation; window.makeKeyAndVisible()
        navigation.pushViewController(controller, animated: true)
        for _ in 0..<100 where controller.presentedViewController?.view.window == nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        let sheet = try XCTUnwrap(controller.presentedViewController)
        let proceedTitle = R.string.localizable.commonProceed(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let proceed = try XCTUnwrap(descendants(sheet.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == proceedTitle })
        await waitUntil { !sheet.isBeingPresented && sheet.transitionCoordinator == nil && sheet.view.window === window }
        try await activate(proceed, in: window)
        for _ in 0..<100 where controller.presentedViewController != nil { try? await Task.sleep(nanoseconds: 10_000_000) }
        let fields = descendants(controller.view).compactMap { $0 as? AnimatedTextField }
        XCTAssertEqual(fields.count, 2)
        for field in fields {
            XCTAssertTrue(controller.animatedTextField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "public-password"))
            field.text = "public-password"; field.sendActions(for: .editingChanged)
        }
        let title = R.string.localizable.commonContinue(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let action = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
        XCTAssertTrue(action.isEnabled)
        return Fixture(window: window, navigation: navigation, controller: controller, presenter: presenter,
                       exporter: exporter, wireframe: wireframe, directory: directory, action: action)
    }

    private func clean(_ f: Fixture) {
        f.window.isHidden = true; f.window.rootViewController = nil
        try? FileManager.default.removeItem(at: f.directory)
    }

    func testRepeatedContinueStartsOnlyOneActualExportBeforeReply() async throws {
        let f = try await readyFixture(); defer { clean(f) }
        f.action.sendActions(for: .touchUpInside)
        f.action.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.exporter.requests, 1, "Continue must own one pending export")
        try? await Task.sleep(nanoseconds: 600_000_000)
        await waitUntil { f.navigation.transitionCoordinator == nil }
        XCTAssertEqual(f.wireframe.exported, 1, "One attempt must open one export screen")
    }

    func testActualQueuedBatchReplyCannotPushDuringAnimatedBack() async throws {
        let f = try await readyFixture(); defer { clean(f) }
        f.action.sendActions(for: .touchUpInside)
        XCTAssertEqual(f.exporter.requests, 1)
        f.navigation.popViewController(animated: true)
        try? await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(f.wireframe.exported, 0, "An issued batch result must not route after Back starts")
        XCTAssertEqual(f.navigation.viewControllers.count, 1)
    }
    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Actual JSON export UI did not settle")
    }

    private func activate(_ button: UIControl, in window: UIWindow) async throws {
        var ancestor = button.superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                break
            }
            ancestor = view.superview
        }
        window.layoutIfNeeded()
        let frame = button.convert(button.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
        XCTAssertLessThanOrEqual(frame.maxY, window.bounds.maxY - window.safeAreaInsets.bottom + 1)
        await waitUntil {
            let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
            return hit === button || hit?.isDescendant(of: button) == true
        }
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true, "Control frame=\(frame), hit=\(String(describing: hit))")
        button.sendActions(for: .touchUpInside)
    }

    private func capture(_ window: UIWindow, name: String) {
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        })
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func closeFailure(_ f: Fixture) async throws {
        await waitUntil { f.controller.presentedViewController?.isBeingPresented == false && f.controller.presentedViewController?.transitionCoordinator == nil }
        let sheet = try XCTUnwrap(f.controller.presentedViewController as? SheetAletViewController)
        let title = R.string.localizable.commonClose(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let close = try XCTUnwrap(descendants(sheet.view).compactMap { $0 as? TriangularedButton }.first { $0.imageWithTitleView?.title == title })
        capture(f.window, name: "json-export-retryable-failure")
        try await activate(close, in: f.window)
        await waitUntil { f.controller.presentedViewController == nil }
    }

    func testActualFailedExportOffersCloseAndSameControlRetry() async throws {
        let f = try await readyFixture(); defer { clean(f) }
        f.exporter.fail = true
        try await activate(f.action, in: f.window)
        XCTAssertFalse(f.action.isEnabled)
        try await closeFailure(f)
        XCTAssertTrue(f.action.isEnabled)
        XCTAssertEqual(f.wireframe.exported, 0)
        f.exporter.fail = false
        try await activate(f.action, in: f.window)
        await waitUntil { f.wireframe.exported == 1 && f.navigation.transitionCoordinator == nil }
        XCTAssertEqual(f.exporter.requests, 2)
        XCTAssertEqual(f.navigation.viewControllers.count, 3)
    }

    func testReturningFromExportDoesNotRepeatWarningAndAllowsNewExport() async throws {
        let f = try await readyFixture(); defer { clean(f) }
        try await activate(f.action, in: f.window)
        await waitUntil { f.wireframe.exported == 1 && f.navigation.transitionCoordinator == nil }
        f.navigation.popViewController(animated: false)
        await waitUntil { f.navigation.topViewController === f.controller && f.controller.view.window != nil }
        XCTAssertNil(f.controller.presentedViewController)
        XCTAssertTrue(f.action.isEnabled)
        try await activate(f.action, in: f.window)
        await waitUntil { f.wireframe.exported == 2 && f.navigation.transitionCoordinator == nil }
        XCTAssertEqual(f.exporter.requests, 2)
    }

    func testCancelledInteractiveBackResumesQueuedSuccess() async throws {
        try await exerciseInteractiveBack(cancel: true)
    }

    func testFinishedInteractiveBackDiscardsQueuedSuccess() async throws {
        try await exerciseInteractiveBack(cancel: false)
    }

    func testCancelledInteractiveBackRetainsFailureAndRetry() async throws {
        try await exerciseInteractiveBack(cancel: true, failure: true)
    }

    private func exerciseInteractiveBack(cancel: Bool, failure: Bool = false) async throws {
        let f = try await readyFixture(); defer { clean(f) }
        let driver = InteractivePopDriver(); f.navigation.delegate = driver
        f.exporter.fail = failure
        try await activate(f.action, in: f.window)
        XCTAssertTrue(f.navigation.popViewController(animated: true) === f.controller)
        await waitUntil { driver.started }
        XCTAssertTrue(driver.isInteractive)
        driver.interaction.update(0.35)
        try? await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(f.wireframe.exported, 0)
        XCTAssertNil(f.controller.presentedViewController)
        if cancel { driver.interaction.cancel() } else { driver.interaction.finish() }
        await waitUntil { driver.completed }
        if cancel && failure {
            try await closeFailure(f)
            XCTAssertTrue(f.action.isEnabled)
            f.exporter.fail = false
            try await activate(f.action, in: f.window)
            await waitUntil { f.wireframe.exported == 1 && f.navigation.transitionCoordinator == nil }
        } else if cancel {
            await waitUntil { f.wireframe.exported == 1 && f.navigation.transitionCoordinator == nil }
            XCTAssertEqual(f.navigation.viewControllers.count, 3)
        } else {
            XCTAssertEqual(f.wireframe.exported, 0)
            XCTAssertEqual(f.navigation.viewControllers.count, 1)
        }
        await waitUntil { f.navigation.transitionCoordinator == nil }
        capture(f.window, name: "json-export-interactive-\(cancel ? "cancel" : "finish")-\(failure ? "failure" : "success")")
    }

    private final class InteractivePopDriver: NSObject, UINavigationControllerDelegate, UIViewControllerAnimatedTransitioning {
        let interaction = UIPercentDrivenInteractiveTransition()
        private(set) var started = false
        private(set) var isInteractive = false
        private(set) var completed = false

        func navigationController(_: UINavigationController, animationControllerFor operation: UINavigationController.Operation,
            from _: UIViewController, to _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            operation == .pop ? self : nil
        }
        func navigationController(_: UINavigationController, interactionControllerFor _: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? { interaction }
        func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval { 0.5 }
        func animateTransition(using context: UIViewControllerContextTransitioning) {
            guard let from = context.view(forKey: .from), let to = context.view(forKey: .to) else {
                XCTFail("Actual navigation transition views are required")
                context.completeTransition(false)
                return
            }
            context.containerView.insertSubview(to, belowSubview: from)
            to.frame = context.containerView.bounds
            isInteractive = context.isInteractive
            started = true
            UIView.animate(withDuration: 0.5, delay: 0, options: .curveLinear) {
                from.transform = CGAffineTransform(translationX: context.containerView.bounds.width, y: 0)
            } completion: { _ in
                from.transform = .identity
                if context.transitionWasCancelled { to.removeFromSuperview() }
                context.completeTransition(!context.transitionWasCancelled)
                self.completed = true
            }
        }
    }

}
