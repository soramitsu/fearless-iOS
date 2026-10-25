import XCTest
import CryptoKit
@testable import fearless
import SoraKeystore
import SoraFoundation
import RobinHood
import Cuckoo
import IrohaCrypto
import UIKit
import TonSwift
import struct SSFModels.ChainAccountModel
import struct SSFModels.Currency

class ExportMnemonicTests: XCTestCase {
    func testMnemonicCreationProvisionsBitcoinMainnetAccount() throws {
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "Bitcoin wallet",
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let operation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
            .newMetaAccountOperation(request: request, isBackuped: true)

        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let account = try XCTUnwrap(wallet.fetch(
            for: UniversalWalletRegistry.bitcoinMainnetChainModel.accountRequest()
        ))

        XCTAssertTrue(account.isChainAccount)
        XCTAssertEqual(account.chainId, UniversalWalletRegistry.bitcoinMainnet.chainId)
        XCTAssertEqual(account.cryptoType, .ecdsa)
        XCTAssertTrue(account.toAddress()?.hasPrefix("bc1") == true)
    }

    func testSubstrateExport() throws {
        // given

        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = "//some//work"
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().randomMnemonic(.entropy128),
            username: "fearless",
            substrateDerivationPath: derivationPath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let createOperation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([createOperation], waitUntilFinished: true)
        let givenAccount = try createOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.set(viewModel: any(MultipleExportGenericViewModelProtocol.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).then { viewModel in
                viewModel.0.actions.first?.handler?()
            }

            when(stub.openConfirmationForMnemonic(any(IRMnemonicProtocol.self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
                confirmationExpectation.fulfill()
            }
        }
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: UInt16(fearless.SNAddressType.genericSubstrate.rawValue)
        )
        let accountResponse = fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: try XCTUnwrap(givenAccount.substrateAccountId),
            publicKey: try XCTUnwrap(givenAccount.substratePublicKey),
            name: givenAccount.name,
            cryptoType: CryptoType(rawValue: givenAccount.substrateCryptoType) ?? .sr25519,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: givenAccount.metaId
        )

        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: givenAccount,
                                                                accounts: [ChainAccountInfo(chain: chain, account: accountResponse)]),
                                                localizationManager: LocalizationManager.shared)

        let interactor = ExportMnemonicInteractor(keystore: keychain,
                                                  repository: AnyDataProviderRepository(repository),
                                                  operationManager: OperationManagerFacade.sharedManager)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateExport()

        // then

        wait(for: [confirmationExpectation], timeout: Constants.defaultExpectationDuration)
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic,
              let substrateDerivationPath = presenter.exportDatas?.first?.derivationPath,
              let cryptoType = presenter.exportDatas?.first?.cryptoType else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "testUsername",
            substrateDerivationPath: substrateDerivationPath,
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: cryptoType,
            defaultChainId: nil
        )
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importOperation = operationFactory.newMetaAccountOperation(request: importRequest, isBackuped: true)
        OperationQueue().addOperations([importOperation], waitUntilFinished: true)
        let importedAccount: MetaAccountModel = try importOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount.substrateCryptoType)
        XCTAssertEqual(try XCTUnwrap(givenAccount.substrateAccountId), importedAccount.substrateAccountId)
        XCTAssertEqual(try XCTUnwrap(givenAccount.substratePublicKey), importedAccount.substratePublicKey)
    }
    
    func testEthereumExport() throws {
        // given

        let keychain = InMemoryKeychain()

        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory.createRepository(for: storageFacade)

        let derivationPath = DerivationPathConstants.testEthereum
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().randomMnemonic(.entropy128),
            username: "fearless",
            substrateDerivationPath: "",
            ethereumDerivationPath: derivationPath,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let createOperation = MetaAccountOperationFactory(keystore: keychain)
            .newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([createOperation], waitUntilFinished: true)
        let givenAccount = try createOperation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        // when

        let view = MockExportGenericViewProtocol()

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.set(viewModel: any(MultipleExportGenericViewModelProtocol.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let wireframe = MockExportMnemonicWireframeProtocol()

        let confirmationExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.present(viewModel: any(SheetAlertPresentableViewModel.self), from: any(ControllerBackedProtocol?.self))).then { param in
                param.0.actions.first?.handler?()
            }

            when(stub.openConfirmationForMnemonic(any(IRMnemonicProtocol.self), wallet: any(fearless.MetaAccountModel.self), from: any(ExportGenericViewProtocol?.self))).then { _ in
                confirmationExpectation.fulfill()
            }
        }
        
        let chain = ChainAccountRecordsFixture.chain(id: "ethereum-export", ethereumBased: true)
        let ethereumPublicKey = try XCTUnwrap(givenAccount.ethereumPublicKey)
        let ethereumAddress = try XCTUnwrap(givenAccount.ethereumAddress)
        let accountResponse = fearless.ChainAccountResponse(
            chainId: chain.chainId,
            accountId: ethereumAddress,
            publicKey: ethereumPublicKey,
            name: givenAccount.name,
            cryptoType: .ecdsa,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: true,
            isChainAccount: false,
            walletId: givenAccount.metaId
        )

        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: givenAccount,
                                                                accounts: [ChainAccountInfo(chain: chain, account: accountResponse)]),
                                                localizationManager: LocalizationManager.shared)

        let interactor = ExportMnemonicInteractor(keystore: keychain,
                                                  repository: AnyDataProviderRepository(repository),
                                                  operationManager: OperationManagerFacade.sharedManager)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        presenter.setup()

        // then

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.activateExport()

        // then

        wait(for: [confirmationExpectation], timeout: Constants.defaultExpectationDuration)
        
        guard let mnemonic = presenter.exportDatas?.first?.mnemonic else {
                  XCTFail()
                  return
              }
        let importRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "testUsername",
            substrateDerivationPath: "",
            ethereumDerivationPath: presenter.exportDatas?.first?.derivationPath ?? DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        let operationFactory = MetaAccountOperationFactory(keystore: keychain)
        let importOperation = operationFactory.newMetaAccountOperation(request: importRequest, isBackuped: true)
        OperationQueue().addOperations([importOperation], waitUntilFinished: true)
        let importedAccount: MetaAccountModel = try importOperation
            .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

        XCTAssertEqual(givenAccount.substrateCryptoType, importedAccount.substrateCryptoType)
        XCTAssertEqual(try XCTUnwrap(givenAccount.substrateAccountId), importedAccount.substrateAccountId)
        XCTAssertEqual(try XCTUnwrap(givenAccount.substratePublicKey), importedAccount.substratePublicKey)
    }
}

@MainActor
final class ExportGenericPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]
    private nonisolated static let words = (1 ... 12).map {
        $0 == 12 ? "publicwordwithanintentionallylongunbrokenpresentationfixture" : "publicword\($0)"
    }

    private nonisolated static let publicData = "PUBLIC-DISPLAY-FIXTURE-" +
        String(repeating: "0123456789abcdef", count: 8)

    private final class Presenter: ExportGenericPresenterProtocol {
        weak var view: ExportGenericViewProtocol?
        let flow: ExportFlow
        let model: MultiExportViewModel
        var setups = 0
        var appearances = 0
        var main = 0
        var accessory = 0
        var substrate = 0
        var ethereum = 0

        init(option: ExportOption, single: Bool = false) {
            let wallet = AccountGenerator.generateMetaAccount()
            flow = single
                ? .single(
                    chain: ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0),
                    address: "public-presentation-fixture",
                    wallet: wallet
                )
                : .multiple(wallet: wallet, accounts: [])
            let models: [ExportGenericViewModelProtocol] = [false, true].map { ethereum in
                if option == .mnemonic {
                    return ExportMnemonicViewModel(
                        option: option,
                        chain: nil,
                        cryptoType: ethereum ? .ecdsa : .sr25519,
                        derivationPath: ethereum ? "public-ethereum-path" : "public-substrate-path",
                        mnemonic: ExportGenericPresentationTests.words,
                        ethereumBased: ethereum
                    )
                }
                return ExportStringViewModel(
                    option: option,
                    chain: nil,
                    cryptoType: ethereum ? .ecdsa : .sr25519,
                    derivationPath: "public-display-path",
                    data: ExportGenericPresentationTests.publicData,
                    ethereumBased: ethereum
                )
            }
            model = MultiExportViewModel(viewModels: models, option: option, flow: flow)
        }

        func setup() { setups += 1; view?.set(viewModel: model) }
        func didLoadView() { appearances += 1 }
        func activateExport() { main += 1 }
        func activateAccessoryOption() { accessory += 1 }
        func didTapExportSubstrateButton() { substrate += 1 }
        func didTapExportEthereumButton() { ethereum += 1 }
    }

    func testExportGenericAllLocalesAndTextSizes() async throws {
        for language in languages {
            for category in categories {
                for (
                    option,
                    optionName
                ) in [(ExportOption.mnemonic, "mnemonic"), (.seed, "seed"), (.keystore, "json")] {
                        let localization = try XCTUnwrap(LocalizationManager(localization: language))
                        let (controller, presenter) = makeController(option: option, localization: localization)
                        let window = try show(controller, category: category)
                        defer { close(window) }
                        await settle(window)
                        let name = "\(optionName)-\(language)-\(category.rawValue)"
                        capture(window, name: name + "-top")
                        XCTAssertEqual(presenter.setups, 1)
                        let details = descendants(controller.view).compactMap { $0 as? DetailsTriangularedView }
                        let source = try XCTUnwrap(details.first)
                        if FWAppearance.exportGenericRestyled {
                            XCTAssertEqual(
                                source.subtitleLabel?.font.pointSize,
                                UIFont.fw(
                                    .bodyL,
                                    locale: localization.selectedLocale,
                                    compatibleWith: controller.traitCollection
                                ).pointSize
                            )
                            assertDetailsFit(source)
                        }
                        if option == .mnemonic {
                            let mnemonic = try XCTUnwrap(
                                descendants(controller.view)
                                    .compactMap { $0 as? TitledMnemonicView }.first
                            )
                            XCTAssertEqual(
                                descendants(controller.view).compactMap { $0 as? TitledMnemonicView }.count,
                                1
                            )
                            let words = wordLabels(mnemonic)
                            XCTAssertEqual(words.count, Self.words.count)
                            XCTAssertEqual(Set(words.compactMap(\.text)), Set(Self.words))
                            if FWAppearance.exportGenericRestyled {
                                XCTAssertEqual(
                                    mnemonic.contentView.wordFontInColumn.pointSize,
                                    UIFont.fw(
                                        .phraseWord,
                                        locale: localization.selectedLocale,
                                        compatibleWith: controller.traitCollection
                                    ).pointSize
                                )
                                assertMnemonicFit(mnemonic)
                            }
                            await reveal(try XCTUnwrap(words.last), in: window)
                            capture(window, name: name + "-last-word")
                        } else if option == .seed {
                            let values = descendants(controller.view).compactMap { $0 as? MultilineTriangularedView }
                            XCTAssertEqual(values.count, 2)
                            for value in values {
                                XCTAssertEqual(value.subtitleLabel.text, Self.publicData)
                                if FWAppearance.exportGenericRestyled {
                                    assertLabelsFit(value)
                                    XCTAssertLessThanOrEqual(
                                        value.titleLabel.frame.maxY,
                                        value.subtitleLabel.frame.minY
                                    )
                                    if category.isAccessibilityCategory {
                                        XCTAssertGreaterThan(value.subtitleLabel.font.pointSize, 20)
                                    }
                                }
                            }
                            await reveal(try XCTUnwrap(values.last), in: window)
                            capture(window, name: name + "-last-value")
                        } else if FWAppearance.exportGenericRestyled {
                            for value in details.dropFirst() {
                                XCTAssertEqual(value.subtitle, Self.publicData)
                                XCTAssertEqual(value.subtitleLabel?.numberOfLines, 1)
                                XCTAssertEqual(value.subtitleLabel?.lineBreakMode, .byTruncatingMiddle)
                                assertDetailsFit(value)
                            }
                        }
                        for (index, action) in actionButtons(controller).enumerated() {
                            await reveal(action, in: window)
                            capture(window, name: name + "-action-\(index)")
                            if FWAppearance.exportGenericRestyled { assertLabelsFit(action) }
                            assertHit(action, in: window)
                        }
                    }
            }
        }
    }

    func testExportGenericCallbacksAndLocalizedRebinding() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let (controller, presenter) = makeController(option: .keystore, localization: localization)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        await settle(window)
        for language in ["en", "ru", "ja"] {
            localization.selectedLocalization = language
            controller.applyLocalization()
            await settle(window)
            let actions = actionButtons(controller)
            XCTAssertEqual(actions.count, 3)
            for action in actions { await activate(action, in: window) }
            capture(window, name: "json-callbacks-\(language)")
        }
        XCTAssertEqual(presenter.setups, 1)
        XCTAssertEqual(presenter.substrate, 3)
        XCTAssertEqual(presenter.ethereum, 3)
        XCTAssertEqual(presenter.accessory, 3)
        XCTAssertEqual(presenter.main, 0)
    }

    func testExportGenericLiveLocaleTypeWidthAndAdvanced() async throws {
        try XCTSkipUnless(FWAppearance.exportGenericRestyled)
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let (controller, presenter) = makeController(option: .mnemonic, localization: localization, single: true)
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let expansion = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? ExpandableActionControl }.first)
        await reveal(expansion, in: window)
        assertHit(expansion, in: window)
        expansion.sendActions(for: .touchUpInside)
        await settle(window)
        localization.selectedLocalization = "ja"
        controller.applyLocalization()
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        await settle(window)
        let locale = localization.selectedLocale
        let mnemonic = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TitledMnemonicView }.first)
        XCTAssertEqual(
            mnemonic.contentView.wordFontInColumn.pointSize,
            UIFont.fw(.phraseWord, locale: locale, compatibleWith: controller.traitCollection).pointSize
        )
        let network = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? DetailsTriangularedView }.first)
        XCTAssertEqual(network.title, R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages))
        XCTAssertTrue(expansion.isActivated)
        for width in [CGFloat(640), 320] {
            window.frame.size.width = width
            await settle(window)
            assertMnemonicFit(mnemonic)
            await reveal(try XCTUnwrap(wordLabels(mnemonic).last), in: window)
            capture(window, name: "live-ja-AX5-width-\(Int(width))")
        }
        XCTAssertEqual(Set(wordLabels(mnemonic).compactMap(\.text)), Set(Self.words))
        let details = descendants(controller.view).compactMap { $0 as? DetailsTriangularedView }
        for (index, detail) in details.enumerated() {
            assertDetailsFit(detail)
            await reveal(detail, in: window)
            capture(window, name: "live-ja-AX5-detail-\(index)")
        }
        await activate(expansion, in: window)
        XCTAssertFalse(expansion.isActivated)
        await activate(expansion, in: window)
        XCTAssertTrue(expansion.isActivated)
        assertMnemonicFit(mnemonic)
        let action = try XCTUnwrap(actionButtons(controller).first)
        await activate(action, in: window)
        XCTAssertEqual(presenter.main, 1)
        XCTAssertEqual(presenter.setups, 1)
        capture(window, name: "live-ja-AX5-action")
    }

    func testExportGenericLiveBoldTextAndRepeatedRefresh() async throws {
        try XCTSkipUnless(FWAppearance.exportGenericRestyled)
        for option in [ExportOption.mnemonic, .seed, .keystore] {
            let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
            let (controller, presenter) = makeController(option: option, localization: localization)
            let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
            defer { close(window) }
            if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
            await settle(window)
            let source = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? DetailsTriangularedView }.first)
            let regular = try XCTUnwrap(source.subtitleLabel?.font)
            let count = actionButtons(controller).count
            if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .bold }
            await settle(window)
            let bold = try XCTUnwrap(source.subtitleLabel?.font)
            XCTAssertGreaterThan(fontWeight(bold), fontWeight(regular))
            XCTAssertEqual(bold.pointSize, regular.pointSize)
            assertDetailsFit(source)
            if let mnemonic = descendants(controller.view).compactMap({ $0 as? TitledMnemonicView }).first {
                assertMnemonicFit(mnemonic)
            }
            await reveal(source, in: window)
            capture(window, name: "bold-\(option)")
            if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
            await settle(window)
            XCTAssertEqual(source.subtitleLabel?.font.fontName, regular.fontName)
            XCTAssertEqual(source.subtitleLabel?.font.pointSize, regular.pointSize)
            for _ in 0 ..< 3 { controller.applyLocalization(); await settle(window) }
            XCTAssertEqual(actionButtons(controller).count, count)
            XCTAssertEqual(presenter.setups, 1)
            for action in actionButtons(controller) { await reveal(action, in: window); assertHit(action, in: window) }
        }
    }

    func testExportGenericRebindingWordCountsAndBoundedJSONPreview() async throws {
        try XCTSkipUnless(FWAppearance.exportGenericRestyled)
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let (controller, presenter) = makeController(option: .mnemonic, localization: localization)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        await settle(window)
        for count in [24, 12] {
            let words = (1 ... count).map { "publicword\($0)" }
            let model = ExportMnemonicViewModel(
                option: .mnemonic,
                chain: nil,
                cryptoType: .sr25519,
                derivationPath: "public-path",
                mnemonic: words,
                ethereumBased: false
            )
            controller
                .set(viewModel: MultiExportViewModel(
                    viewModels: [model, model],
                    option: .mnemonic,
                    flow: presenter.flow
                ))
            await settle(window)
            let views = descendants(controller.view).compactMap { $0 as? TitledMnemonicView }
            XCTAssertEqual(views.count, 1)
            let mnemonic = try XCTUnwrap(views.first)
            XCTAssertEqual(wordLabels(mnemonic).count, count)
            XCTAssertEqual(Set(wordLabels(mnemonic).compactMap(\.text)), Set(words))
            assertMnemonicFit(mnemonic)
            await reveal(try XCTUnwrap(wordLabels(mnemonic).last), in: window)
            capture(window, name: "rebind-\(count)-words")
        }
        close(window)
        let (jsonController, jsonPresenter) = makeController(option: .keystore, localization: localization)
        let jsonWindow = try show(jsonController, category: .accessibilityExtraExtraExtraLarge)
        defer { close(jsonWindow) }
        await settle(jsonWindow)
        let data = String(repeating: Self.publicData, count: 40)
        let models = [false, true].map { ethereum in
            ExportStringViewModel(
                option: .keystore,
                chain: nil,
                cryptoType: .sr25519,
                derivationPath: nil,
                data: data,
                ethereumBased: ethereum
            )
        }
        jsonController
            .set(viewModel: MultiExportViewModel(viewModels: models, option: .keystore, flow: jsonPresenter.flow))
        await settle(jsonWindow)
        XCTAssertEqual(actionButtons(jsonController).count, 3)
        let value = try XCTUnwrap(descendants(jsonController.view).compactMap { $0 as? DetailsTriangularedView }.last)
        XCTAssertEqual(value.subtitle, data)
        XCTAssertEqual(value.subtitleLabel?.numberOfLines, 1)
        XCTAssertEqual(value.subtitleLabel?.lineBreakMode, .byTruncatingMiddle)
        XCTAssertLessThan(value.bounds.height, 500)
        assertDetailsFit(value)
        await reveal(value, in: jsonWindow)
        capture(jsonWindow, name: "large-public-JSON-bounded-preview")
    }

    private func fontWeight(_ font: UIFont) -> CGFloat {
        let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
        return (traits?[.weight] as? NSNumber).map { CGFloat(truncating: $0) } ?? 0
    }

    private func assertDetailsFit(_ view: DetailsTriangularedView, file: StaticString = #filePath, line: UInt = #line) {
        assertLabelsFit(view, file: file, line: line)
        if let subtitle = view.subtitleLabel {
            XCTAssertLessThanOrEqual(view.titleLabel.frame.maxY, subtitle.frame.minY, file: file, line: line)
            XCTAssertLessThanOrEqual(subtitle.frame.maxY, view.bounds.height + 0.5, file: file, line: line)
        }
    }

    private func assertMnemonicFit(_ view: TitledMnemonicView, file: StaticString = #filePath, line: UInt = #line) {
        for word in wordLabels(view) {
            assertHorizontallyContained(word, in: view, file: file, line: line)
            let frame = word.convert(word.bounds, to: view)
            XCTAssertGreaterThanOrEqual(frame.minY, view.titleLabel.frame.maxY, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, view.bounds.height + 0.5, file: file, line: line)
        }
    }

    private func makeController(option: ExportOption, localization: LocalizationManager, single: Bool = false)
        -> (ExportGenericViewController, Presenter) {
        let main: LocalizableResource<String>? = option == .seed ? nil : LocalizableResource { locale in
            option == .mnemonic ? R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
                : R.string.localizable.accountExportAction(preferredLanguages: locale.rLanguages)
        }
        let accessory: LocalizableResource<String>? = option == .keystore ? LocalizableResource { locale in
            R.string.localizable.commonChangePassword(preferredLanguages: locale.rLanguages)
        } : nil
        let factory = UIFactory()
        let controller = ExportGenericViewController(
            uiFactory: factory,
            binder: ExportGenericViewModelBinder(uiFactory: factory),
            mainTitle: main,
            accessoryTitle: accessory
        )
        let presenter = Presenter(option: option, single: single)
        presenter.view = controller
        controller.presenter = presenter
        controller.localizationManager = localization
        return (controller, presenter)
    }

    private func wordLabels(_ view: UIView) -> [UILabel] {
        descendants(view).compactMap { $0 as? UILabel }.filter { $0.text?.hasPrefix("publicword") == true }
    }

    private func actionButtons(_ controller: UIViewController) -> [TriangularedButton] {
        descendants(controller.view).compactMap { $0 as? TriangularedButton }
            .filter { isVisible($0) }
            .sorted {
                $0.convert($0.bounds, to: controller.view).minY < $1.convert($1.bounds, to: controller.view).minY
            }
    }

    private func assertLabelsFit(_ view: UIView, file: StaticString = #filePath, line: UInt = #line) {
        for label in descendants(view).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
            let fit = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(fit.height, label.bounds.height + 0.5, file: file, line: line)
            assertHorizontallyContained(label, in: view, file: file, line: line)
        }
    }

    private func assertHorizontallyContained(
        _ child: UIView,
        in parent: UIView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = child.convert(child.bounds, to: parent)
        XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, parent.bounds.width + 0.5, file: file, line: line)
    }

    private func assertHit(
        _ control: UIControl,
        in window: UIWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = control.convert(control.bounds, to: window)
        XCTAssertGreaterThanOrEqual(control.bounds.height, 44, file: file, line: line)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true, file: file, line: line)
    }

    private func activate(_ control: UIControl, in window: UIWindow) async {
        await reveal(control, in: window)
        assertHit(control, in: window)
        control.sendActions(for: .touchUpInside)
        await settle(window)
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
                (view.layer.animationKeys() ?? []).contains {
                    $0.hasPrefix("bounds") || $0.hasPrefix("position") || view.layer
                        .animation(forKey: $0) is CATransition
                }
            }) { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Export presentation animations did not settle")
    }

    private func isVisible(_ view: UIView) -> Bool {
        guard !view.isHidden, view.alpha > 0 else { return false }
        return view.superview.map { isVisible($0) } ?? true
    }

    private func close(_ window: UIWindow) { window.isHidden = true; window.rootViewController = nil }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }

    private func capture(_ window: UIWindow, name: String) {
        let image = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        })
        image.name = "export-generic-" + (FWAppearance.exportGenericRestyled ? "adaptive-" : "rollback-") + name
        image.lifetime = .keepAlways
        add(image)
        let text = descendants(window).compactMap { view -> String? in
            guard let label = view as? UILabel else { return nil }
            return "text=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
        }.joined(separator: "\n")
        let metrics = XCTAttachment(string: text)
        metrics.name = "export-generic-metrics-" + name
        metrics.lifetime = .keepAlways
        add(metrics)
    }
}


/// Public deterministic fixtures exercise the released creation and export paths.
final class MnemonicExportOwnershipTests: XCTestCase {
    private let phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private let otherPhrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testHealthyStoredPhraseRecreatesDisplayedAccount() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let info = try substrateInfo(wallet)
        let output = record(wallet: wallet, accounts: [info], keys: keys)
        XCTAssertEqual(output.models.count, 1)
        XCTAssertTrue(output.errors.isEmpty)
        XCTAssertEqual(output.models.first?.mnemonic.toString(), phrase)
    }

    func testReplacedEntropyIsRejectedBeforePhraseIsShown() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: otherPhrase).entropy(),
                         with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let output = record(wallet: wallet, accounts: [try substrateInfo(wallet)], keys: keys)
        XCTAssertTrue(output.models.isEmpty, "The phrase for a different key must never be displayed")
        XCTAssertEqual(output.errors.count, 1)
    }

    func testReplacedDerivationPathIsRejectedBeforePhraseIsShown() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        try keys.saveKey(Data("//Other".utf8),
                         with: KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId))
        let output = record(wallet: wallet, accounts: [try substrateInfo(wallet)], keys: keys)
        XCTAssertTrue(output.models.isEmpty, "Correct words with the wrong path restore a different account")
        XCTAssertEqual(output.errors.count, 1)
    }

    func testGeneratedDedicatedAccountsUseVerifiedWalletRoot() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let chains = [UniversalWalletRegistry.bitcoinMainnetChainModel, UniversalWalletRegistry.tairaChainModel]
        let accounts = try chains.map { chain in
            ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        }
        let output = record(wallet: wallet, accounts: accounts, keys: keys)
        XCTAssertEqual(output.models.count, 2, "Generated dedicated accounts share the verified wallet root")
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testSingleCustomAccountUsesResolvedAccountTag() throws {
        let keys = InMemoryKeychain()
        let original = try makeWallet(keys)
        let imported = MetaAccountOperationFactory(keystore: keys).importChainAccountOperation(
            request: ChainAccountImportMnemonicRequest(
                mnemonic: try IRMnemonicCreator().mnemonic(fromList: otherPhrase), username: original.name,
                derivationPath: "//Custom", cryptoType: .sr25519, isEthereum: false, meta: original,
                chainId: "mnemonic-source-chain"
            )
        )
        OperationQueue().addOperations([imported], waitUntilFinished: true)
        let wallet = try imported.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let chain = ChainAccountRecordsFixture.chain(id: "mnemonic-display-chain")
        let custom = try XCTUnwrap(wallet.chainAccounts.first { $0.chainId == "mnemonic-source-chain" })
        let address = try custom.accountId.toAddress(using: .substrate(chain.addressPrefix))
        let output = MnemonicOwnershipOutput(expectation: expectation(description: "single result"))
        let interactor = makeInteractor(keys, output: output)
        interactor.fetchExportDataForAddress(address, chain: chain, wallet: wallet)
        wait(for: [output.expectation], timeout: 10)
        XCTAssertEqual(output.models.count, 1)
        XCTAssertEqual(output.models.first?.mnemonic.toString(), otherPhrase)
        XCTAssertEqual(output.models.first?.derivationPath, "//Custom")
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testWholeWalletProofRequiresEveryVerifiedIdentityAndExactPhrase() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        let exports = try fullAccounts(wallet).map { try reader.fetch(wallet: wallet, info: $0) }
        let proof = try XCTUnwrap(reader.backupProof(wallet: wallet, exports: exports))
        XCTAssertTrue(proof.covers(exports[0].mnemonic, wallet: wallet))
        XCTAssertFalse(proof.covers(try IRMnemonicCreator().mnemonic(fromList: otherPhrase), wallet: wallet))
        XCTAssertFalse(proof.covers(exports[0].mnemonic, wallet: wallet.replacingIsBackuped(true)))
        for index in exports.indices {
            XCTAssertNil(reader.backupProof(wallet: wallet, exports: exports.enumerated().filter { $0.offset != index }.map(\.element)))
        }
        XCTAssertNil(reader.backupProof(wallet: wallet, exports: Array(repeating: exports[0], count: exports.count)))
    }

    func testSubstrateAlgorithmsAndEthereumRoundTripOriginalKeys() throws {
        for crypto: CryptoType in [.sr25519, .ed25519, .ecdsa] {
            let keys = InMemoryKeychain()
            let wallet = try makeWallet(keys, crypto: crypto)
            let output = record(wallet: wallet, accounts: try fullAccounts(wallet), keys: keys)
            XCTAssertEqual(output.models.count, 7)
            XCTAssertTrue(output.models.allSatisfy { $0.backupProof != nil })
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: try XCTUnwrap(output.models.first?.mnemonic), username: "Restored public fixture",
                substrateDerivationPath: "//Fixture", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: crypto, defaultChainId: nil
            )
            let operation = MetaAccountOperationFactory(keystore: InMemoryKeychain()).newMetaAccountOperation(request: request, isBackuped: false)
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            let restored = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertEqual(restored.substratePublicKey, wallet.substratePublicKey)
            XCTAssertEqual(restored.substrateAccountId, wallet.substrateAccountId)
            XCTAssertEqual(restored.ethereumAddress, wallet.ethereumAddress)
            XCTAssertEqual(restored.ethereumPublicKey, wallet.ethereumPublicKey)
            XCTAssertEqual(restored.chainAccounts, wallet.chainAccounts)
        }
    }

    func testMissingEthereumPathLeavesVerifiedRecoveryMaterialWithoutWalletProof() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        try keys.deleteKey(for: KeystoreTagV2.ethereumDerivationTagForMetaId(wallet.metaId))
        let output = record(wallet: wallet, accounts: try fullAccounts(wallet), keys: keys)
        XCTAssertEqual(output.models.count, 6)
        XCTAssertEqual(output.notShown.count, 1)
        XCTAssertTrue(output.models.allSatisfy { $0.backupProof == nil })
        XCTAssertEqual(output.notShown.first?.chain.chainId, "mnemonic-ethereum")
    }

    func testMalformedPathBytesCannotBeTreatedAsAnEmptyPath() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        try keys.saveKey(Data([0xff, 0xff]), with: KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId))
        XCTAssertThrowsError(try VerifiedMnemonicExportReader(keystore: keys).fetch(wallet: wallet, info: substrateInfo(wallet)))
    }

    func testVerifiedCustomPhraseDoesNotStandForOtherWalletAccounts() throws {
        let keys = InMemoryKeychain()
        let original = try makeWallet(keys)
        let operation = MetaAccountOperationFactory(keystore: keys).importChainAccountOperation(request: ChainAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: otherPhrase), username: original.name,
            derivationPath: "//Custom", cryptoType: .sr25519, isEthereum: false, meta: original, chainId: "mnemonic-custom"
        ))
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let customChain = ChainAccountRecordsFixture.chain(id: "mnemonic-custom")
        let custom = ChainAccountInfo(chain: customChain, account: try XCTUnwrap(wallet.fetch(for: customChain.accountRequest())))
        let output = record(wallet: wallet, accounts: try fullAccounts(wallet) + [custom], keys: keys)
        XCTAssertEqual(output.models.count, 8)
        XCTAssertTrue(output.notShown.isEmpty)
        XCTAssertTrue(output.models.allSatisfy { $0.backupProof == nil })
        XCTAssertEqual(output.models.last?.mnemonic.toString(), otherPhrase)
    }

    func testVerifiedSingleAccountNeverReceivesWholeWalletProof() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let info = try substrateInfo(wallet)
        let output = MnemonicOwnershipOutput(expectation: expectation(description: "single result"))
        let interactor = makeInteractor(keys, output: output)
        interactor.fetchExportDataForAddress(try XCTUnwrap(info.account.toAddress()), chain: info.chain, wallet: wallet)
        wait(for: [output.expectation], timeout: 10)
        XCTAssertEqual(output.models.count, 1)
        XCTAssertNil(output.models.first?.backupProof)
    }

    func testLegacyNativeTonPhraseRetainsItsExactBytesAndVerifiedIdentity() throws {
        let keys = InMemoryKeychain()
        let wallet = try LegacyNativeTonFixture.wallet()
        let bytes = Data(LegacyNativeTonFixture.phrase.utf8)
        try keys.saveKey(bytes, with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let chain = ChainAccountRecordsFixture.chain(id: "-239")
        let info = ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        let output = record(wallet: wallet, accounts: [info], keys: keys)
        XCTAssertEqual(output.models.count, 1)
        XCTAssertEqual(output.models.first?.mnemonic.entropy(), bytes)
        XCTAssertNotNil(output.models.first?.backupProof)
        try keys.saveKey(Data(otherPhrase.utf8), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        XCTAssertThrowsError(try VerifiedMnemonicExportReader(keystore: keys).fetch(wallet: wallet, info: info))
    }

    func testVerificationNeverWritesOrDeletesStoredSecrets() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let probe = MnemonicReadOnlyKeys(keys)
        let reader = VerifiedMnemonicExportReader(keystore: probe)
        let exports = try fullAccounts(wallet).map { try reader.fetch(wallet: wallet, info: $0) }
        XCTAssertNotNil(reader.backupProof(wallet: wallet, exports: exports))
        XCTAssertEqual(probe.writeAttempts, 0)
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: otherPhrase).entropy(), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        XCTAssertThrowsError(try reader.fetch(wallet: wallet, info: substrateInfo(wallet)))
        XCTAssertEqual(probe.writeAttempts, 0)
    }

    func testEveryDedicatedRecipeVerifiesItsActualOriginalPublicKey() throws {
        let keys = InMemoryKeychain()
        var wallet = try makeWallet(keys)
        let cohorts: [(String, Data, CryptoType)] = [
            (UniversalWalletRegistry.bitcoinTestnet.chainId, try BitcoinKeyDerivation.deriveAccount(mnemonic: phrase, network: .testnet).publicKey, .ecdsa),
            (UniversalWalletRegistry.solanaMainnet.chainId, try SolanaKeyDerivation.deriveAccount(mnemonic: phrase).publicKey, .ed25519),
            (UniversalWalletRegistry.solanaDevnet.chainId, try SolanaKeyDerivation.deriveAccount(mnemonic: phrase).publicKey, .ed25519),
            (UniversalWalletRegistry.nexus.chainId, try IrohaKeyDerivation.deriveAccount(mnemonic: phrase).publicKey, .ed25519),
            (UniversalWalletRegistry.tonMainnetRegistryEntry.chainId, try TonKeyDerivation.deriveAccount(mnemonic: phrase).publicKey, .ed25519)
        ]
        wallet = wallet.replacingChainAccounts(wallet.chainAccounts.union(cohorts.map {
            ChainAccountModel(chainId: $0.0, accountId: $0.1, publicKey: $0.1, cryptoType: $0.2.rawValue, ethereumBased: false)
        }))
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        for (chainId, _, _) in cohorts {
            let chain = ChainAccountRecordsFixture.chain(id: chainId)
            let info = ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
            XCTAssertEqual(try reader.fetch(wallet: wallet, info: info).mnemonic.toString(), phrase)
        }
    }

    func testMarkedRawSeedBridgeOnlyExportsDedicatedKeysItRecreates() throws {
        let keys = InMemoryKeychain()
        let walletSeed = Data(repeating: 0, count: 32)
        let bridgePhrase = try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: walletSeed)
        let wallet = try UniversalWalletAccountProvisioning.addingAppOwnedAccounts(
            to: AccountGenerator.generateMetaAccount(), mnemonic: bridgePhrase
        )
        try keys.saveKey(walletSeed, with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keys.saveKey(Data(UniversalWalletSeedBridge.contract.utf8), with: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId))
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let info = ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        XCTAssertEqual(try reader.fetch(wallet: wallet, info: info).mnemonic.toString(), bridgePhrase)
        try keys.deleteKey(for: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId))
        XCTAssertThrowsError(try reader.fetch(wallet: wallet, info: info))
    }

    func testDifferentDedicatedChainPhraseIsVerifiedWithoutClaimingWalletBackup() throws {
        let keys = InMemoryKeychain()
        let original = try makeWallet(keys)
        let bitcoin = try BitcoinKeyDerivation.deriveAccount(mnemonic: otherPhrase)
        let stored = ChainAccountModel(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: bitcoin.publicKey, publicKey: bitcoin.publicKey, cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false)
        let wallet = original.replacingChainAccounts(Set(original.chainAccounts.filter { $0.chainId != stored.chainId }).union([stored]))
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: otherPhrase).entropy(),
                         with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: bitcoin.publicKey))
        let output = record(wallet: wallet, accounts: try fullAccounts(wallet), keys: keys)
        XCTAssertEqual(output.models.count, 7)
        XCTAssertTrue(output.notShown.isEmpty)
        XCTAssertTrue(output.models.allSatisfy { $0.backupProof == nil })
        XCTAssertEqual(output.models.first { $0.chain.chainId == stored.chainId }?.mnemonic.toString(), otherPhrase)
    }

    func testCorruptRootKeepsVerifiedHistoricalChildPhraseAvailable() throws {
        let keys = InMemoryKeychain()
        let original = try makeWallet(keys)
        let bitcoin = try BitcoinKeyDerivation.deriveAccount(mnemonic: otherPhrase)
        let stored = ChainAccountModel(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId,
            accountId: bitcoin.publicKey, publicKey: bitcoin.publicKey, cryptoType: CryptoType.ecdsa.rawValue, ethereumBased: false)
        let wallet = original.replacingChainAccounts(Set(original.chainAccounts.filter { $0.chainId != stored.chainId }).union([stored]))
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: otherPhrase).entropy(),
            with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: bitcoin.publicKey))
        try keys.saveKey(Data([0xff]), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let chain = UniversalWalletRegistry.bitcoinMainnetChainModel
        let info = ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
        let readOnly = MnemonicReadOnlyKeys(keys)
        let output = record(wallet: wallet, accounts: [info], keys: readOnly)
        XCTAssertEqual(output.models.count, 1, "A damaged unrelated root must not hide verified child material")
        XCTAssertEqual(output.models.first?.mnemonic.toString(), otherPhrase)
        XCTAssertNil(output.models.first?.backupProof)
        XCTAssertEqual(readOnly.writeAttempts, 0)
    }

    func testCorruptRootKeepsHistoricalChildSigningMaterialAndExactTransaction() throws {
        let keys = InMemoryKeychain()
        let wallet = try BitcoinTestWallet.wallet()
        let chain = BitcoinTestWallet.chain
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let entropy = try IRMnemonicCreator().mnemonic(fromList: BitcoinTestWallet.mnemonic).entropy()
        try keys.saveKey(entropy, with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: account.accountId))
        let readOnly = MnemonicReadOnlyKeys(keys)
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: readOnly)
        let healthy = try XCTUnwrap(provider.mnemonic(for: wallet, chain: chain))
        let inputs = [BitcoinSpendableUtxo(address: BitcoinTestWallet.address,
            txid: String(repeating: "11", count: 32), valueSats: 100000, vout: 0)]
        let outputs = [BitcoinPaymentOutput(address: BitcoinTestWallet.recipient, valueSats: 50000)]
        let before = try BitcoinTransactionBuilder.buildP2wpkhTransaction(mnemonic: healthy,
            inputs: inputs, outputs: outputs, changeAddress: BitcoinTestWallet.address, feeSats: 1000)
        try keys.saveKey(Data([0xff]), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let afterPhrase = try XCTUnwrap(provider.mnemonic(for: wallet, chain: chain))
        let after = try BitcoinTransactionBuilder.buildP2wpkhTransaction(mnemonic: afterPhrase,
            inputs: inputs, outputs: outputs, changeAddress: BitcoinTestWallet.address, feeSats: 1000)
        XCTAssertEqual(afterPhrase, healthy)
        XCTAssertEqual(after.txHex, before.txHex, "The original child must produce the exact same signed transaction")
        XCTAssertEqual(after.txid, before.txid)
        XCTAssertEqual(readOnly.writeAttempts, 0)
    }

    func testDamagedRootNeverPermitsUnverifiedHistoricalChildMaterial() throws {
        let keys = InMemoryKeychain()
        let wallet = try BitcoinTestWallet.wallet()
        let account = try XCTUnwrap(wallet.fetch(for: BitcoinTestWallet.chain.accountRequest()))
        try keys.saveKey(Data([0xff]), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: phrase).entropy(),
            with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: account.accountId))
        let readOnly = MnemonicReadOnlyKeys(keys)
        XCTAssertThrowsError(try VerifiedMnemonicExportReader(keystore: readOnly).fetch(wallet: wallet,
            info: ChainAccountInfo(chain: BitcoinTestWallet.chain, account: account)))
        XCTAssertThrowsError(try KeychainUniversalWalletMnemonicProvider(keystore: readOnly).mnemonic(for: wallet, chain: BitcoinTestWallet.chain))
        try keys.deleteKey(for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: account.accountId))
        XCTAssertThrowsError(try KeychainUniversalWalletMnemonicProvider(keystore: readOnly).mnemonic(for: wallet, chain: BitcoinTestWallet.chain))
        XCTAssertEqual(readOnly.writeAttempts, 0)
    }

    func testInvalidRootSeedBridgeKeepsOnlyVerifiedHistoricalChildMaterial() throws {
        let keys = InMemoryKeychain()
        let wallet = try BitcoinTestWallet.wallet()
        let account = try XCTUnwrap(wallet.fetch(for: BitcoinTestWallet.chain.accountRequest()))
        try keys.saveKey(Data(UniversalWalletSeedBridge.contract.utf8), with: KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId))
        try keys.saveKey(Data([0xff]), with: KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
        try keys.saveKey(IRMnemonicCreator().mnemonic(fromList: BitcoinTestWallet.mnemonic).entropy(),
            with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId, accountId: account.accountId))
        let readOnly = MnemonicReadOnlyKeys(keys)
        let reader = VerifiedMnemonicExportReader(keystore: readOnly)
        let exported = try reader.fetch(wallet: wallet, info: ChainAccountInfo(chain: BitcoinTestWallet.chain, account: account))
        XCTAssertEqual(exported.mnemonic.toString(), BitcoinTestWallet.mnemonic)
        XCTAssertNil(reader.backupProof(wallet: wallet, exports: [exported]))
        XCTAssertEqual(try KeychainUniversalWalletMnemonicProvider(keystore: readOnly).mnemonic(for: wallet, chain: BitcoinTestWallet.chain), BitcoinTestWallet.mnemonic)
        XCTAssertEqual(readOnly.writeAttempts, 0)
    }

    func testNewInvalidRequestCancelsEarlierHeldVerification() throws {
        let keys = InMemoryKeychain()
        let wallet = try makeWallet(keys)
        let info = try substrateInfo(wallet)
        let queue = OperationQueue(); queue.isSuspended = true
        defer { queue.isSuspended = false }
        let output = MnemonicOwnershipOutput(expectation: expectation(description: "latest invalid request"))
        output.expectation.assertForOverFulfill = true
        let interactor = ExportMnemonicInteractor(keystore: keys,
            repository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())),
            operationManager: OperationManager(operationQueue: queue))
        interactor.presenter = output
        interactor.fetchExportDataForWallet(wallet: wallet, accounts: [info])
        interactor.fetchExportDataForAddress("not-an-address", chain: info.chain, wallet: wallet)
        wait(for: [output.expectation], timeout: 2)
        let drained = expectation(description: "old work completed")
        queue.addBarrierBlock { DispatchQueue.main.async { drained.fulfill() } }
        queue.isSuspended = false
        wait(for: [drained], timeout: 10)
        XCTAssertTrue(output.models.isEmpty)
        XCTAssertEqual(output.errors.count, 1)
    }

    private func fullAccounts(_ wallet: MetaAccountModel) throws -> [ChainAccountInfo] {
        let chains = [ChainAccountRecordsFixture.chain(id: "mnemonic-substrate"),
                      ChainAccountRecordsFixture.chain(id: "mnemonic-ethereum", ethereumBased: true),
                      UniversalWalletRegistry.bitcoinMainnetChainModel, UniversalWalletRegistry.tairaChainModel,
                      UniversalWalletRegistry.solanaMainnetChainModel,
                      ChainAccountRecordsFixture.chain(id: UniversalWalletRegistry.bitcoinTestnet.chainId),
                      ChainAccountRecordsFixture.chain(id: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId)]
        return try chains.map { ChainAccountInfo(chain: $0, account: try XCTUnwrap(wallet.fetch(for: $0.accountRequest()))) }
    }

    private func makeWallet(_ keys: KeystoreProtocol, crypto: CryptoType = .sr25519) throws -> MetaAccountModel {
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: phrase), username: "Public mnemonic fixture",
            substrateDerivationPath: "//Fixture", ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: crypto, defaultChainId: nil
        )
        let operation = MetaAccountOperationFactory(keystore: keys).newMetaAccountOperation(request: request, isBackuped: false)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(wallet, settings: settings,
            importOperation: operation as? PersistenceBoundKeychainOperation)
        return wallet
    }

    private func substrateInfo(_ wallet: MetaAccountModel) throws -> ChainAccountInfo {
        let chain = ChainAccountRecordsFixture.chain(id: "mnemonic-substrate")
        return ChainAccountInfo(chain: chain, account: try XCTUnwrap(wallet.fetch(for: chain.accountRequest())))
    }

    private func makeInteractor(_ keys: KeystoreProtocol, output: MnemonicOwnershipOutput) -> ExportMnemonicInteractor {
        let interactor = ExportMnemonicInteractor(
            keystore: keys,
            repository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())),
            operationManager: OperationManager()
        )
        interactor.presenter = output
        return interactor
    }

    private func record(wallet: MetaAccountModel, accounts: [ChainAccountInfo], keys: KeystoreProtocol) -> MnemonicOwnershipOutput {
        let output = MnemonicOwnershipOutput(expectation: expectation(description: "wallet result"))
        let interactor = makeInteractor(keys, output: output)
        interactor.fetchExportDataForWallet(wallet: wallet, accounts: accounts)
        wait(for: [output.expectation], timeout: 10)
        return output
    }
}

private final class MnemonicOwnershipOutput: ExportMnemonicInteractorOutputProtocol {
    let expectation: XCTestExpectation
    var models: [ExportMnemonicData] = []
    var errors: [Error] = []
    var notShown: [ExportMnemonicNotShown] = []
    init(expectation: XCTestExpectation) { self.expectation = expectation }
    func didReceive(exportDatas: [ExportMnemonicData]) { models = exportDatas; expectation.fulfill() }
    func didReceive(exportDatas: [ExportMnemonicData], notShown: [ExportMnemonicNotShown]) {
        self.notShown = notShown
        models = exportDatas
        if models.isEmpty, let error = notShown.first?.error { errors.append(error) }
        expectation.fulfill()
    }
    func didReceive(error: Error) { errors.append(error); expectation.fulfill() }
}

private final class MnemonicReadOnlyKeys: KeystoreProtocol {
    private let base: KeystoreProtocol
    private(set) var writeAttempts = 0
    init(_ base: KeystoreProtocol) { self.base = base }
    func addKey(_: Data, with _: String) throws { writeAttempts += 1; throw KeystoreError.unexpectedFail }
    func updateKey(_: Data, with _: String) throws { writeAttempts += 1; throw KeystoreError.unexpectedFail }
    func deleteKey(for _: String) throws { writeAttempts += 1; throw KeystoreError.unexpectedFail }
    func fetchKey(for identifier: String) throws -> Data { try base.fetchKey(for: identifier) }
    func checkKey(for identifier: String) throws -> Bool { try base.checkKey(for: identifier) }
}

@MainActor
final class MnemonicExportPresentationTests: XCTestCase {
    private final class SheetPresenter: SheetAlertPresentable {}
    private final class Wireframe: ExportMnemonicWireframeProtocol, ExportSeedWireframeProtocol {
        var renderSheets = false
        var sheets: [SheetAlertPresentableViewModel] = []
        var jsonRoutes = 0
        var confirmations = 0
        var backWhilePresented: [Bool] = []
        func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
            sheets.append(viewModel)
            if renderSheets { SheetPresenter().present(viewModel: viewModel, from: view) }
        }
        func back(view: ExportGenericViewProtocol?) {
            backWhilePresented.append(view?.controller.presentedViewController != nil)
            if renderSheets { ExportSeedWireframe().back(view: view) }
            else { view?.controller.navigationController?.popViewController(animated: false) }
        }
        func openConfirmationForMnemonic(_: IRMnemonicProtocol, wallet _: MetaAccountModel, from _: ExportGenericViewProtocol?) { confirmations += 1 }
        func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?) {
            jsonRoutes += 1
            ExportSeedWireframe().showJsonExport(flow: flow, from: view)
        }
    }

    private struct Fixture {
        let controller: ExportGenericViewController
        let presenter: ExportMnemonicPresenter
        let wireframe: Wireframe
        let queue: OperationQueue
    }

    private func fixture(language: String, held: Bool = false) throws -> Fixture {
        let keys = InMemoryKeychain()
        let request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: "legal winner thank year wave sausage worth useful legal winner thank yellow"),
            username: "Public phrase recovery fixture", substrateDerivationPath: "//Fixture",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum, cryptoType: .sr25519, defaultChainId: nil
        )
        let operation = MetaAccountOperationFactory(keystore: keys).newMetaAccountOperation(request: request, isBackuped: false)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        try AccountCreationHelper.selectMetaAccount(wallet, settings: settings,
            importOperation: operation as? PersistenceBoundKeychainOperation)
        try keys.saveKey(Data("//Wrong".utf8), with: KeystoreTagV2.substrateDerivationTagForMetaId(wallet.metaId))
        let chains = [ChainAccountRecordsFixture.chain(id: "public-substrate"), ChainAccountRecordsFixture.chain(id: "public-ethereum", ethereumBased: true)]
        let accounts = try chains.map { ChainAccountInfo(chain: $0, account: try XCTUnwrap(wallet.fetch(for: $0.accountRequest()))) }
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: wallet, accounts: accounts), localizationManager: localization)
        let queue = OperationQueue(); queue.isSuspended = held
        let interactor = ExportMnemonicInteractor(keystore: keys,
            repository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())),
            operationManager: OperationManager(operationQueue: queue))
        let wireframe = Wireframe()
        let factory = UIFactory()
        let controller = ExportGenericViewController(uiFactory: factory, binder: ExportGenericViewModelBinder(uiFactory: factory),
            mainTitle: LocalizableResource { R.string.localizable.commonContinue(preferredLanguages: $0.rLanguages) }, accessoryTitle: nil)
        controller.presenter = presenter; controller.localizationManager = localization
        presenter.view = controller; presenter.wireframe = wireframe; presenter.interactor = interactor
        interactor.presenter = presenter
        return Fixture(controller: controller, presenter: presenter, wireframe: wireframe, queue: queue)
    }

    private final class HeldSeedRequests: ExportSeedInteractorInputProtocol {
        var requests = 0
        func fetchExportDataForAddress(_: String, chain _: ChainModel, wallet _: MetaAccountModel) { requests += 1 }
        func fetchExportDataForWallet(_: MetaAccountModel, accounts _: [ChainAccountInfo]) { requests += 1 }
        func didBackupSeed(wallet _: MetaAccountModel, completion _: @escaping (Result<Void, Error>) -> Void) {
            XCTFail("Cancelling initial seed warning must not record backup")
        }
    }

    func testAutomaticInitialCancelWaitsForDismissalAndFencesHeldResults() async throws {
        for useSeed in [false, true] {
            for animated in [true, false] {
                let animationsWereEnabled = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(animated)
                defer { UIView.setAnimationsEnabled(animationsWereEnabled) }
                let f = try fixture(language: "en", held: true)
                f.wireframe.renderSheets = true
                let seed = ExportSeedPresenter(flow: f.presenter.flow, localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")))
                let requests = HeldSeedRequests()
                seed.interactor = requests; seed.wireframe = f.wireframe
                let controller: ExportGenericViewController
                if useSeed {
                    let factory = UIFactory()
                    controller = ExportGenericViewController(uiFactory: factory, binder: ExportGenericViewModelBinder(uiFactory: factory),
                        mainTitle: LocalizableResource { R.string.localizable.commonContinue(preferredLanguages: $0.rLanguages) }, accessoryTitle: nil)
                    controller.presenter = seed; controller.localizationManager = seed.localizationManager; seed.view = controller
                } else { controller = f.controller }
                let (window, navigation) = try host(controller, category: .large)
                defer { f.queue.isSuspended = false; window.isHidden = true; window.rootViewController = nil }
                await waitUntil {
                    guard let sheet = controller.presentedViewController else { return false }
                    return sheet.view.window === window && !sheet.isBeingPresented && sheet.transitionCoordinator == nil
                }
                let cancel = try XCTUnwrap(f.wireframe.sheets.first?.actions.last?.button)
                try await activate(cancel, in: window)
                f.queue.isSuspended = false
                if useSeed {
                    XCTAssertEqual(requests.requests, 1)
                    seed.didReceive(exportData: [], notShown: [ExportSeedNotShown(chain: f.presenter.flow.exportingAccounts[0].chain,
                        error: UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet)])
                }
                await waitUntil { navigation.viewControllers.count == 1 && navigation.transitionCoordinator == nil && controller.presentedViewController == nil }
                await waitUntil { f.queue.operationCount == 0 }
                XCTAssertEqual(f.wireframe.backWhilePresented, [false], "Navigation must wait for the actual warning dismissal")
                XCTAssertEqual(f.wireframe.sheets.count, 1, "Cancel must fence late recovery guidance before dismissal finishes")
                XCTAssertEqual(f.wireframe.jsonRoutes, 0)
                capture(window, name: "json-initial-cancel-settled-\(useSeed ? "seed" : "mnemonic")-\(animated ? "animated" : "instant")")
            }
        }
    }

    func testAutomaticMnemonicRecoveryToJsonPresentsAttachedPasswordWarning() async throws {
        try await exerciseAutomaticRecovery(language: "en", category: .large, width: 320)
    }

    func testAutomaticWarningActionsFitAtAccessibilitySize() async throws {
        for language in ["ru", "zh-Hans"] {
            try await exerciseAutomaticRecovery(language: language, category: .accessibilityExtraExtraExtraLarge, width: 320)
        }
    }

    func testAutomaticRecoveryControlsAllLocalesAndTypeSizes() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                try await exerciseAutomaticRecovery(language: language, category: category, width: 320)
            }
        }
        for language in ["ru", "zh-Hans"] {
            try await exerciseAutomaticRecovery(language: language, category: .accessibilityExtraExtraExtraLarge, width: 390)
        }
    }

    private func exerciseAutomaticRecovery(language: String, category: UIContentSizeCategory, width: CGFloat) async throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = language
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let name = "\(language)-\(category.rawValue)-\(Int(width))"
        let f = try fixture(language: language)
        f.wireframe.renderSheets = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: width, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        window.rootViewController = navigation; window.makeKeyAndVisible()
        navigation.pushViewController(f.controller, animated: true)
        defer { window.isHidden = true; window.rootViewController = nil }
        await waitUntil { f.controller.presentedViewController?.view.window != nil && f.presenter.exportDatas != nil && f.controller.presentedViewController?.isBeingPresented == false && f.controller.presentedViewController?.transitionCoordinator == nil }
        capture(window, name: "json-recovery-automatic-initial-warning-top-" + name)
        let initialButton = try XCTUnwrap(f.wireframe.sheets.first?.actions.first?.button)
        await waitUntil { self.isReachable(initialButton, in: window) }
        assertActionTextFits(initialButton)
        capture(window, name: "json-recovery-automatic-initial-warning-" + name)
        try await activate(initialButton, in: window)
        await waitUntil { f.wireframe.sheets.count == 2 && f.controller.presentedViewController?.view.window != nil && f.controller.presentedViewController?.isBeingPresented == false && f.controller.presentedViewController?.transitionCoordinator == nil }
        let recoveryButton = try XCTUnwrap(f.wireframe.sheets.last?.actions.first?.button)
        await waitUntil { self.isReachable(recoveryButton, in: window) }
        assertActionTextFits(recoveryButton)
        capture(window, name: "json-recovery-automatic-incomplete-warning-" + name)
        try await activate(recoveryButton, in: window)
        recoveryButton.sendActions(for: .touchUpInside)
        await waitUntil { navigation.topViewController is AccountExportPasswordViewController }
        XCTAssertEqual(f.wireframe.jsonRoutes, 1, "Repeated taps during dismissal must own one JSON navigation")
        let password = try XCTUnwrap(navigation.topViewController as? AccountExportPasswordViewController)
        await waitUntil { password.presentedViewController?.view.window != nil && password.presentedViewController?.isBeingPresented == false && password.presentedViewController?.transitionCoordinator == nil }
        capture(window, name: "json-warning-automatic-recovery-transition-" + name)
        let sheet = try XCTUnwrap(password.presentedViewController as? SheetAletViewController)
        XCTAssertTrue(sheet.view.window === window)
        let proceed = R.string.localizable.commonProceed(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        let controls = descendants(sheet.view).compactMap { $0 as? TriangularedButton }
        XCTAssertEqual(controls.filter { $0.imageWithTitleView?.title == proceed }.count, 1)
        for (index, control) in controls.enumerated() {
            await waitUntil { self.isReachable(control, in: window) }
            assertActionTextFits(control)
            capture(window, name: "json-warning-automatic-action-\(index)-" + name)
        }
        let cancel = R.string.localizable.commonCancel(preferredLanguages: [language])
        let cancelButton = try XCTUnwrap(controls.first { $0.imageWithTitleView?.title == cancel })
        var ancestor: UIView? = cancelButton
        var ancestors: [String] = []
        while let current = ancestor {
            ancestors.append("\(type(of: current)): alpha=\(current.alpha), hidden=\(current.isHidden), interactive=\(current.isUserInteractionEnabled), frame=\(current.frame)")
            ancestor = current.superview
        }
        let alphaEvidence = XCTAttachment(string: ancestors.joined(separator: "\n"))
        alphaEvidence.name = "json-warning-ancestor-alpha-" + name; alphaEvidence.lifetime = .keepAlways; add(alphaEvidence)
        XCTAssertEqual(sheet.presentationController?.containerView?.alpha, 1, "The completed modal must be visible and receive touches")

        await waitUntil { self.isReachable(cancelButton, in: window) }
        try await activate(cancelButton, in: window)
        await waitUntil { navigation.topViewController === f.controller && navigation.transitionCoordinator == nil }
        XCTAssertNil(f.controller.presentedViewController, "Returning from JSON cancellation must not stack another initial warning")
    }

    private func assertActionTextFits(_ button: UIControl) {
        for label in descendants(button).compactMap({ $0 as? UILabel }) {
            var ancestor: UIView? = label
            var visible = true
            while let view = ancestor, view !== button {
                visible = visible && !view.isHidden
                ancestor = view.superview
            }
            guard visible, label.text?.isEmpty == false else { continue }
            let frame = label.convert(label.bounds, to: button)
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "Complete action text must remain inside its control")
            XCTAssertLessThanOrEqual(frame.maxX, button.bounds.width + 1, "Complete action text must remain inside its control")
            XCTAssertGreaterThanOrEqual(frame.minY, 0, "Complete action text must remain inside its control")
            XCTAssertLessThanOrEqual(frame.maxY, button.bounds.height + 1, "Complete action text must remain inside its control")
            XCTAssertLessThanOrEqual(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height,
                                    label.bounds.height + 1, "Action text must not truncate")
        }
    }

    private func isReachable(_ button: UIControl, in window: UIWindow) -> Bool {
        window.layoutIfNeeded()
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
        let isInsideWindow = frame.minX >= 0 && frame.maxX <= window.bounds.width + 1
            && frame.minY >= 0 && frame.maxY <= window.bounds.height + 1
        return isInsideWindow && button.window === window && (hit === button || hit?.isDescendant(of: button) == true)
    }

    func testActualPartialPhraseWarningAndJsonRecoveryControlsInEveryLocale() async throws {
        for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let f = try fixture(language: language)
                let (window, navigation) = try host(f.controller, category: category)
                defer { window.isHidden = true; window.rootViewController = nil }
                await waitUntil { f.wireframe.sheets.count == 1 && f.presenter.exportDatas != nil }
                XCTAssertEqual(f.presenter.exportDatas?.count, 1, "The healthy Ethereum recovery material remains available")
                XCTAssertNil(f.presenter.exportDatas?.first?.backupProof)
                let warning = try XCTUnwrap(f.wireframe.sheets.first)
                let warningController = try await show(warning, from: f.controller, window: window)
                try await activate(try XCTUnwrap(warning.actions.first?.button), in: window)
                await waitUntil { warningController.presentingViewController == nil && f.wireframe.sheets.count == 2 }
                let model = f.wireframe.sheets[1]
                let bundle = try XCTUnwrap(Bundle(path: XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))))
                XCTAssertEqual(model.title, bundle.localizedString(forKey: "export.mnemonic.unavailable.title", value: nil, table: "Localizable"))
                XCTAssertFalse(try XCTUnwrap(model.message).contains("%@"))
                let sheet = try await show(model, from: f.controller, window: window)
                let labels = descendants(sheet.view).compactMap { $0 as? UILabel }
                for label in labels.filter({ $0.text == model.title || $0.text == model.message }) {
                    let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(required.height, label.bounds.height + 1, "Complete \(language) phrase recovery warning")
                }
                capture(window, name: "mnemonic-partial-\(language)-\(category.rawValue)")
                let messageLabel = try XCTUnwrap(labels.first { $0.text == model.message })
                var messageAncestor = messageLabel.superview
                while let ancestor = messageAncestor {
                    if let scroll = ancestor as? UIScrollView {
                        scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top,
                            scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                        window.layoutIfNeeded()
                        let messageBottom = messageLabel.convert(CGRect(x: 0, y: max(0, messageLabel.bounds.height - messageLabel.font.lineHeight),
                            width: messageLabel.bounds.width, height: messageLabel.font.lineHeight), to: window)
                        let viewport = scroll.convert(scroll.bounds, to: window)
                        XCTAssertGreaterThanOrEqual(messageBottom.minY, viewport.minY - 1, "Last recovery guidance line must be reachable")
                        XCTAssertLessThanOrEqual(messageBottom.maxY, viewport.maxY + 1, "Last recovery guidance line must be reachable")
                        break
                    }
                    messageAncestor = ancestor.superview
                }
                capture(window, name: "mnemonic-partial-guidance-\(language)-\(category.rawValue)")
                let button = try XCTUnwrap(model.actions.first?.button)
                try await activate(button, in: window)
                await waitUntil { navigation.topViewController is AccountExportPasswordViewController }
                await waitUntil {
                    guard let password = navigation.topViewController as? AccountExportPasswordViewController,
                          let warning = password.presentedViewController else { return false }
                    return navigation.transitionCoordinator == nil && warning.view.window === window
                        && !warning.isBeingPresented && warning.transitionCoordinator == nil
                }
                XCTAssertEqual(f.wireframe.jsonRoutes, 1)
                XCTAssertEqual(f.wireframe.confirmations, 0)
                capture(window, name: "mnemonic-json-recovery-\(language)-\(category.rawValue)")
            }
        }
    }

    func testActualPopDuringHeldVerificationSuppressesLateWordsAndRecoveryWarning() async throws {
        let f = try fixture(language: "en", held: true)
        let (window, navigation) = try host(f.controller, category: .large)
        defer { f.queue.isSuspended = false; window.isHidden = true; window.rootViewController = nil }
        await waitUntil { f.queue.operationCount > 0 && f.wireframe.sheets.count == 1 }
        XCTAssertEqual(f.wireframe.sheets.count, 1)
        await waitUntil { navigation.transitionCoordinator == nil && f.controller.view.window === window }
        try? await Task.sleep(nanoseconds: 50_000_000)
        navigation.popViewController(animated: false)
        f.queue.isSuspended = false
        await waitUntil { f.queue.operationCount == 0 }
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(f.presenter.exportDatas)
        XCTAssertEqual(f.wireframe.sheets.count, 1)
        XCTAssertEqual(f.wireframe.jsonRoutes, 0)
        f.presenter.activateExport()
        XCTAssertEqual(f.wireframe.confirmations, 0)
        XCTAssertEqual(navigation.viewControllers.count, 1)
        capture(window, name: "mnemonic-abandoned-held-verification")
    }

    func testActualWarningCancelDiscardsHeldVerification() async throws {
        let f = try fixture(language: "en", held: true)
        let (window, navigation) = try host(f.controller, category: .large)
        defer { f.queue.isSuspended = false; window.isHidden = true; window.rootViewController = nil }
        await waitUntil { f.queue.operationCount > 0 && f.wireframe.sheets.count == 1 }
        let warning = try XCTUnwrap(f.wireframe.sheets.first)
        _ = try await show(warning, from: f.controller, window: window)
        try await activate(try XCTUnwrap(warning.actions.last?.button), in: window)
        f.queue.isSuspended = false
        await waitUntil { f.queue.operationCount == 0 && navigation.viewControllers.count == 1 }
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(f.presenter.exportDatas)
        XCTAssertEqual(f.wireframe.sheets.count, 1)
        XCTAssertEqual(f.wireframe.confirmations, 0)
        capture(window, name: "mnemonic-warning-cancel-held-verification")
    }

    func testRejectedNativeTonPhraseDoesNotOfferUnsupportedJsonExport() throws {
        let wallet = try LegacyNativeTonFixture.wallet()
        let chain = ChainAccountRecordsFixture.chain(id: "-239")
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)]),
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")))
        let wireframe = Wireframe(); presenter.wireframe = wireframe
        presenter.didReceive(exportDatas: [], notShown: [ExportMnemonicNotShown(chain: chain, error: UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet)])
        let warning = try XCTUnwrap(wireframe.sheets.first)
        XCTAssertTrue(warning.actions.isEmpty)
        XCTAssertNotNil(warning.closeAction)
        XCTAssertEqual(warning.message, R.string.localizable.universalRecoveryMismatchMessage(preferredLanguages: ["en"]))
        XCTAssertEqual(wireframe.jsonRoutes, 0)
    }

    private func host(_ controller: UIViewController, category: UIContentSizeCategory) throws -> (UIWindow, UINavigationController) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        navigation.setViewControllers([navigation.viewControllers[0], controller], animated: false)
        window.rootViewController = navigation; window.makeKeyAndVisible(); window.layoutIfNeeded()
        return (window, navigation)
    }

    private func show(_ model: SheetAlertPresentableViewModel, from host: UIViewController, window: UIWindow) async throws -> SheetAletViewController {
        let sheet = SheetAletViewController(viewModel: model)
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        await withCheckedContinuation { continuation in host.present(sheet, animated: false) { continuation.resume() } }
        window.layoutIfNeeded()
        return sheet
    }

    private func activate(_ button: UIControl, in window: UIWindow) async throws {
        var ancestor = button.superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView { scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false); break }
            ancestor = view.superview
        }
        window.layoutIfNeeded()
        let frame = button.convert(button.bounds, to: window)
        XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
        XCTAssertLessThanOrEqual(frame.maxY, window.bounds.maxY - window.safeAreaInsets.bottom + 1)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true, "Control \(String(describing: (button as? TriangularedButton)?.imageWithTitleView?.title)) frame=\(frame) hit=\(String(describing: hit))")
        button.sendActions(for: .touchUpInside)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Owned mnemonic UI did not settle")
    }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func capture(_ window: UIWindow, name: String) {
        window.layoutIfNeeded()
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        })
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

@MainActor
final class SeedShareOwnershipTests: XCTestCase {
    private final class Wireframe: ExportSeedWireframeProtocol {
        var render = true
        var sheets: [SheetAlertPresentableViewModel] = []
        var sharesWhilePresented: [Bool] = []
        var completions: [SharingCompletionHandler] = []
        var results: [Bool] = []
        private let sharing = ExportSeedWireframe()
        func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
            sheets.append(viewModel)
            if render { sharing.present(viewModel: viewModel, from: view) }
        }
        func share(source: UIActivityItemSource, from view: ControllerBackedProtocol?, with completion: SharingCompletionHandler?) {
            sharesWhilePresented.append(view?.controller.presentedViewController != nil)
            if let completion { completions.append(completion) }
            if render { sharing.share(source: source, from: view) { [weak self] completed in
                self?.results.append(completed); completion?(completed)
            } }
        }
        func back(view: ExportGenericViewProtocol?) { ExportSeedWireframe().back(view: view) }
        func showJsonExport(flow: ExportFlow, from view: ExportGenericViewProtocol?) { ExportSeedWireframe().showJsonExport(flow: flow, from: view) }
    }
    private final class Interactor: ExportSeedInteractorInputProtocol {
        weak var presenter: ExportSeedPresenter?
        var backupCalls = 0
        let data = ExportSeedData(seed: Data(repeating: 0x41, count: 32), derivationPath: nil,
            chain: ChainAccountRecordsFixture.chain(id: "public-seed-share-fixture"), cryptoType: .sr25519)
        func fetchExportDataForAddress(_: String, chain _: ChainModel, wallet _: MetaAccountModel) { deliver() }
        func fetchExportDataForWallet(_: MetaAccountModel, accounts _: [ChainAccountInfo]) { deliver() }
        func deliver() { presenter?.didReceive(exportData: [data], notShown: []) }
        func didBackupSeed(wallet _: MetaAccountModel, completion: @escaping (Result<Void, Error>) -> Void) {
            backupCalls += 1; completion(.success(()))
        }
    }
    private struct Fixture {
        let presenter: ExportSeedPresenter
        let view: ExportGenericViewController
        let wireframe: Wireframe
        let interactor: Interactor
        let window: UIWindow
        var value: String { interactor.data.seed.toHex(includePrefix: true) }
        func close() { view.dismiss(animated: false); window.isHidden = true; window.rootViewController = nil }
    }
    private func fixture(render: Bool = true, language: String = "en", category: UIContentSizeCategory = .large) throws -> Fixture {
        let locale = try XCTUnwrap(LocalizationManager(localization: language))
        let presenter = ExportSeedPresenter(flow: .multiple(wallet: AccountGenerator.generateMetaAccount(), accounts: []), localizationManager: locale)
        let factory = UIFactory()
        let view = ExportGenericViewController(uiFactory: factory, binder: ExportGenericViewModelBinder(uiFactory: factory), mainTitle: nil, accessoryTitle: nil)
        let wireframe = Wireframe(); wireframe.render = render
        let interactor = Interactor(); interactor.presenter = presenter
        presenter.wireframe = wireframe; presenter.interactor = interactor; presenter.view = view
        view.presenter = presenter; view.localizationManager = locale
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        navigation.setViewControllers([navigation.viewControllers[0], view], animated: false)
        window.rootViewController = navigation; window.makeKeyAndVisible(); window.layoutIfNeeded()
        return Fixture(presenter: presenter, view: view, wireframe: wireframe, interactor: interactor, window: window)
    }
    func testActualSeedWarningWaitsForDismissalBeforeSystemShare() async throws {
        let f = try fixture(); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
        try await activate(try XCTUnwrap(f.wireframe.sheets[0].actions.first?.button), in: f.window)
        await waitUntil { f.view.presentedViewController == nil }
        let row = try XCTUnwrap(descendants(f.view.view).compactMap { $0 as? MultilineTriangularedView }.first)
        reveal(row, in: f.window)
        assertHit(row, in: f.window)
        let gesture = try XCTUnwrap(row.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first,
            "This seed-share entry is intentionally Debug-only; this test must not enable it in Release")
        f.view.perform(NSSelectorFromString("exportGestureHandler:"), with: gesture)
        await waitUntil { f.wireframe.sheets.count == 2 && self.settled(f.view.presentedViewController, in: f.window) }
        capture(f.window, "seed-share-warning-before-export")
        try await activate(try XCTUnwrap(f.wireframe.sheets[1].actions.first?.button), in: f.window)
        await waitUntil { self.settled(f.view.presentedViewController as? UIActivityViewController, in: f.window) }
        XCTAssertEqual(f.wireframe.sharesWhilePresented, [false], "System share must begin after warning dismissal completes")
        XCTAssertTrue(f.view.presentedViewController is UIActivityViewController, "Actual system share must be attached")
        XCTAssertEqual(f.interactor.backupCalls, 0)
        capture(f.window, "seed-share-after-export")
        if let activity = f.view.presentedViewController {
            let controls = descendants(activity.view).map { view in
                "\(type(of: view)) label=\(view.accessibilityLabel ?? "") identifier=\(view.accessibilityIdentifier ?? "") text=\((view as? UILabel)?.text ?? "") frame=\(view.convert(view.bounds, to: f.window))"
            }.joined(separator: "\n")
            let attachment = XCTAttachment(string: controls); attachment.name = "seed-share-system-control-inventory"; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
    func testDuplicateWarningsAndSharesHaveOneOwner() async throws {
        let f = try fixture(render: false); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 }
        f.wireframe.sheets[0].dismissCompletion?()
        f.presenter.didTapStringExport(f.value); f.presenter.didTapStringExport(f.value)
        XCTAssertEqual(f.wireframe.sheets.count, 2, "A pending warning must have one owner")
        f.wireframe.sheets[1].actions.first?.beforeDismissal?()
        f.wireframe.sheets[1].dismissCompletion?()
        f.wireframe.sheets[1].actions.first?.handler?()
        f.presenter.share(f.value)
        XCTAssertEqual(f.wireframe.completions.count, 1, "A pending system share must have one owner")
    }
    func testCancelledShareCanRetryAndDuplicateCallbacksCannotMarkBackup() async throws {
        let f = try fixture(render: false); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 }
        f.wireframe.sheets[0].dismissCompletion?()
        f.presenter.share(f.value)
        let first = try XCTUnwrap(f.wireframe.completions.first)
        first(false); first(true)
        XCTAssertEqual(f.interactor.backupCalls, 0)
        f.presenter.share(f.value)
        XCTAssertEqual(f.wireframe.completions.count, 2)
        f.wireframe.completions[1](true); f.wireframe.completions[1](true)
        XCTAssertEqual(f.interactor.backupCalls, 1)
    }
    func testWarningActionAndShareReplyAfterDepartureCannotMarkBackup() async throws {
        let f = try fixture(render: false); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 }
        f.wireframe.sheets[0].dismissCompletion?()
        f.presenter.share(f.value)
        f.presenter.didTapStringExport(f.value)
        f.presenter.didLeaveView()
        f.wireframe.sheets.last?.actions.first?.handler?()
        f.wireframe.completions.first?(true)
        XCTAssertEqual(f.wireframe.completions.count, 1)
        XCTAssertEqual(f.interactor.backupCalls, 0)
    }
    func testActualExternalShareDismissalReportsCancellationAndAllowsRetry() async throws {
        let f = try fixture(); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
        try await activate(try XCTUnwrap(f.wireframe.sheets[0].actions.first?.button), in: f.window)
        await waitUntil { f.view.presentedViewController == nil }
        f.presenter.share(f.value)
        await waitUntil { self.settled(f.view.presentedViewController as? UIActivityViewController, in: f.window) }
        let activity = try XCTUnwrap(f.view.presentedViewController as? UIActivityViewController)
        let oldCompletion = activity.completionWithItemsHandler
        await withCheckedContinuation { continuation in f.view.dismiss(animated: true) { continuation.resume() } }
        await waitUntil { f.wireframe.results.count == 1 }
        XCTAssertEqual(f.wireframe.results, [false], "External dismissal must terminate the owned share as cancelled")
        oldCompletion?(nil, true, nil, nil)
        XCTAssertEqual(f.interactor.backupCalls, 0, "An abandoned system sheet must not acknowledge backup later")
        f.presenter.share(f.value)
        await waitUntil { self.settled(f.view.presentedViewController as? UIActivityViewController, in: f.window) }
        XCTAssertTrue(f.view.presentedViewController is UIActivityViewController)
        XCTAssertEqual(f.wireframe.sharesWhilePresented.count, 2)
        capture(f.window, "seed-share-external-dismiss-retry")
    }
    func testDetachedSeedHostDeclinesShareAndAcknowledgesCancellation() async throws {
        let f = try fixture(render: false)
        await waitUntil { f.wireframe.sheets.count == 1 }
        f.wireframe.sheets[0].dismissCompletion?()
        f.close()
        var results: [Bool] = []
        ExportSeedWireframe().share(source: TextSharingSource(message: "public share fixture"), from: f.view) { results.append($0) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(results, [false], "A detached seed exporter cannot own a system share")
    }
    func testExternalWarningDismissalDoesNotStrandOrReviveItsExport() async throws {
        let f = try fixture(); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
        try await activate(try XCTUnwrap(f.wireframe.sheets[0].actions.first?.button), in: f.window)
        await waitUntil { f.view.presentedViewController == nil }
        f.presenter.didTapStringExport(f.value)
        await waitUntil { f.wireframe.sheets.count == 2 && self.settled(f.view.presentedViewController, in: f.window) }
        let abandoned = f.wireframe.sheets[1]
        await withCheckedContinuation { continuation in f.view.dismiss(animated: true) { continuation.resume() } }
        f.presenter.didTapStringExport(f.value)
        await waitUntil { f.wireframe.sheets.count == 3 && self.settled(f.view.presentedViewController, in: f.window) }
        XCTAssertEqual(f.wireframe.sheets.count, 3, "External warning dismissal must leave export retry reachable")
        abandoned.actions.first?.beforeDismissal?(); abandoned.dismissCompletion?(); abandoned.actions.first?.handler?()
        XCTAssertTrue(f.wireframe.completions.isEmpty, "An abandoned warning must not launch a share over its replacement")
    }
    func testExternalInitialWarningDismissalKeepsPartialRecoveryAttached() async throws {
        let f = try fixture(); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
        f.presenter.didReceive(exportData: [f.interactor.data], notShown: [ExportSeedNotShown(
            chain: f.interactor.data.chain, error: UniversalWalletRootRecoveryError.phraseDoesNotMatchWallet)])
        await withCheckedContinuation { continuation in f.view.dismiss(animated: true) { continuation.resume() } }
        await waitUntil { f.wireframe.sheets.count == 2 && self.settled(f.view.presentedViewController, in: f.window) }
        XCTAssertEqual(f.wireframe.sheets.count, 2)
        XCTAssertTrue(settled(f.view.presentedViewController, in: f.window), "Partial recovery must attach after the abandoned warning")
        XCTAssertEqual(f.wireframe.sheets.last?.title, R.string.localizable.exportSeedUnavailableTitle(preferredLanguages: ["en"]))
        XCTAssertTrue(f.wireframe.completions.isEmpty)
        XCTAssertEqual(f.interactor.backupCalls, 0)
    }
    func testActualWarningCancelKeepsRetryReachableAtLargeText() async throws {
        for language in ["ru", "zh-Hans"] {
            let f = try fixture(language: language, category: .accessibilityExtraExtraExtraLarge); defer { f.close() }
            await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
            try await activate(try XCTUnwrap(f.wireframe.sheets[0].actions.first?.button), in: f.window)
            await waitUntil { f.view.presentedViewController == nil }
            f.presenter.didTapStringExport(f.value)
            await waitUntil { f.wireframe.sheets.count == 2 && self.settled(f.view.presentedViewController, in: f.window) }
            let warning = try XCTUnwrap(f.view.presentedViewController as? SheetAletViewController)
            let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: [language])
            let cancel = try XCTUnwrap(descendants(warning.view).compactMap { $0 as? TriangularedButton }.first {
                $0.imageWithTitleView?.title == cancelTitle
            })
            reveal(cancel, in: f.window); assertHit(cancel, in: f.window)
            let label = try XCTUnwrap(cancel.wrappingLabel)
            XCTAssertEqual(label.text, cancelTitle)
            XCTAssertLessThanOrEqual(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height,
                label.bounds.height + 1, "Complete cancel text must fit")
            capture(f.window, "seed-share-warning-cancel-" + language + "-AX5")
            try await activate(cancel, in: f.window)
            await waitUntil { f.view.presentedViewController == nil }
            XCTAssertTrue(f.wireframe.completions.isEmpty)
            f.presenter.didTapStringExport(f.value)
            await waitUntil { f.wireframe.sheets.count == 3 && self.settled(f.view.presentedViewController, in: f.window) }
            XCTAssertEqual(f.wireframe.sheets.count, 3)
            XCTAssertEqual(f.interactor.backupCalls, 0)
        }
    }
    func testCurrentSystemCompletionCanMarkOnceBeforeDismissal() async throws {
        let f = try fixture(); defer { f.close() }
        await waitUntil { f.wireframe.sheets.count == 1 && self.settled(f.view.presentedViewController, in: f.window) }
        try await activate(try XCTUnwrap(f.wireframe.sheets[0].actions.first?.button), in: f.window)
        await waitUntil { f.view.presentedViewController == nil }
        f.presenter.share(f.value)
        await waitUntil { self.settled(f.view.presentedViewController as? UIActivityViewController, in: f.window) }
        let activity = try XCTUnwrap(f.view.presentedViewController as? UIActivityViewController)
        // Exercise the production activity completion boundary. This does not
        // claim that an external share destination was invoked or completed.
        let completion = try XCTUnwrap(activity.completionWithItemsHandler)
        completion(nil, true, nil, nil); completion(nil, true, nil, nil)
        await withCheckedContinuation { continuation in f.view.dismiss(animated: true) { continuation.resume() } }
        XCTAssertEqual(f.wireframe.results, [true])
        XCTAssertEqual(f.interactor.backupCalls, 1)
    }
    private func settled(_ controller: UIViewController?, in window: UIWindow) -> Bool {
        guard let controller else { return false }
        return controller.view.window === window && !controller.isBeingPresented && controller.transitionCoordinator == nil
    }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<150 { if condition() { return }; try? await Task.sleep(nanoseconds: 20_000_000) }
    }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func reveal(_ view: UIView, in window: UIWindow) {
        var ancestor = view.superview
        while let next = ancestor {
            if let scroll = next as? UIScrollView { scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false); break }
            ancestor = next.superview
        }
        window.layoutIfNeeded()
    }
    private func assertHit(_ view: UIView, in window: UIWindow) {
        let frame = view.convert(view.bounds, to: window)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === view || hit?.isDescendant(of: view) == true, "Actual export control must receive its center hit")
    }
    private func activate(_ button: UIControl, in window: UIWindow) async throws {
        reveal(button, in: window); assertHit(button, in: window)
        button.sendActions(for: .touchUpInside)
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    private func capture(_ window: UIWindow, _ name: String) {
        window.layoutIfNeeded()
        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

@MainActor
final class ExactTonMnemonicExportTests: XCTestCase {
    // Public IC07 GW-T2a historical writer identity; no current-derived expectation.
    private let phrase = "cluster notice abandon  frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"
    private let address = "UQDvaKHy6izOBPGdot4wtkje_R2PF_RQl86qPA3e4p3-P84h"
    private let publicKey = Data([0x2d, 0x42, 0x79, 0xca, 0xe4, 0xf7, 0x17, 0xc8, 0x0f, 0x4b, 0x56, 0xf4, 0xd6, 0x7b, 0x6c, 0x18, 0x9d, 0x5f, 0xcd, 0x26, 0x0a, 0x2a, 0x75, 0x67, 0x3c, 0x80, 0x14, 0xfd, 0x41, 0xda, 0x2e, 0xa3])

    private struct Fixture {
        let controller: ExportGenericViewController
        let presenter: ExportMnemonicPresenter
        let wallet: MetaAccountModel
        let keys: InMemoryKeychain
        let chain: ChainModel
    }

    private func fixture(irregular: Bool, language: String = "en", historical: (phrase: String, address: String, publicKey: String)? = nil) throws -> Fixture {
        let phrase = historical?.phrase ?? (irregular ? self.phrase : LegacyNativeTonFixture.phrase)
        let native: LegacyTonAccount
        if let historical {
            native = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(TonSwift.Address.parse(historical.address)),
                publicKey: Data(hexStringSSF: historical.publicKey), contractVersion: "v4R2")
        } else {
            native = irregular
                ? try LegacyTonAccount(serializedAddress: JSONEncoder().encode(TonSwift.Address.parse(address)), publicKey: publicKey, contractVersion: "v4R2")
                : try LegacyNativeTonFixture.account()
        }
        let wallet = MetaAccountModel(metaId: "public-ton-exact-export", name: "Public legacy TON backup", substrateAccountId: nil,
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: "-239", assetsVisibility: [],
            hasBackup: false, favouriteChainIds: [], legacyTonAccount: native)
        let keys = InMemoryKeychain()
        try keys.saveKey(Data(phrase.utf8), with: KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let chain = ChainAccountRecordsFixture.chain(id: "-239")
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let localization = try XCTUnwrap(LocalizationManager(localization: language))
        let presenter = ExportMnemonicPresenter(flow: .multiple(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)]), localizationManager: localization)
        let interactor = ExportMnemonicInteractor(keystore: keys,
            repository: AnyDataProviderRepository(AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade())),
            operationManager: OperationManager())
        let factory = UIFactory()
        let controller = ExportGenericViewController(uiFactory: factory, binder: ExportGenericViewModelBinder(uiFactory: factory),
            mainTitle: LocalizableResource { R.string.localizable.commonContinue(preferredLanguages: $0.rLanguages) }, accessoryTitle: nil)
        controller.presenter = presenter; controller.localizationManager = localization
        presenter.view = controller; presenter.interactor = interactor; presenter.wireframe = ExportMnemonicWireframe()
        interactor.presenter = presenter
        return Fixture(controller: controller, presenter: presenter, wallet: wallet, keys: keys, chain: chain)
    }

    func testActualVerifiedIrregularExportHasExactCopyInsteadOfAmbiguousWordTiles() async throws {
        let fixture = try fixture(irregular: true)
        let (window, _) = try host(fixture.controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await closeWarning(fixture.controller, window: window)
        await waitUntil { fixture.presenter.exportDatas?.count == 1 }
        XCTAssertEqual(fixture.presenter.exportDatas?.first?.mnemonic.toString(), phrase)
        XCTAssertEqual(fixture.wallet.legacyTonAccount?.publicKey, publicKey)
        XCTAssertFalse(descendants(fixture.controller.view).contains { $0 is TitledMnemonicView }, "Numbered word tiles cannot convey significant empty entries and line breaks")
        let copy = descendants(fixture.controller.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-export-copy-exact" }
        capture(window, "irregular-ton-exact-copy")
        XCTAssertNotNil(copy, "Verified legacy phrase needs an explicit exact-byte recovery copy route")
    }

    func testCanonicalNativePhraseRetainsExistingWordPresentation() async throws {
        let fixture = try fixture(irregular: false)
        let (window, _) = try host(fixture.controller)
        defer { window.isHidden = true; window.rootViewController = nil }
        try await closeWarning(fixture.controller, window: window)
        await waitUntil { fixture.presenter.exportDatas?.count == 1 }
        XCTAssertEqual(fixture.presenter.exportDatas?.first?.mnemonic.toString(), LegacyNativeTonFixture.phrase)
        XCTAssertTrue(descendants(fixture.controller.view).contains { $0 is TitledMnemonicView })
        XCTAssertFalse(descendants(fixture.controller.view).contains { $0.accessibilityIdentifier == "ton-export-copy-exact" })
    }

    func testActualCopyPreservesHistoricalIdentityAndLateControlCannotCopyAfterBack() async throws {
        let fixture = try fixture(irregular: true)
        let (window, navigation) = try host(fixture.controller)
        defer { window.isHidden = true; window.rootViewController = nil; UIPasteboard.general.items = [] }
        await waitUntil { fixture.presenter.exportDatas?.count == 1 && fixture.controller.presentedViewController != nil }
        let copy = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-export-copy-exact" })
        UIPasteboard.general.string = "public sentinel before warning"
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "public sentinel before warning")
        try await closeWarning(fixture.controller, window: window)
        reveal(copy, in: window); copy.sendActions(for: .touchUpInside)
        let copied = try XCTUnwrap(UIPasteboard.general.string)
        XCTAssertEqual(Data(copied.utf8), Data(phrase.utf8))
        let selected = try XCTUnwrap(LegacyTonMnemonic.importCandidates(copied).first { $0.publicKey == publicKey })
        XCTAssertEqual(selected.address, address)
        let request = MetaAccountImportMnemonicRequest(mnemonic: selected.mnemonic, username: "Public exact recovery",
            substrateDerivationPath: "", ethereumDerivationPath: "", cryptoType: .ed25519, defaultChainId: "-239")
        let operation = MetaAccountOperationFactory(keystore: fixture.keys).newMetaAccountOperation(request: request, isBackuped: false)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let restored = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        XCTAssertEqual(restored.legacyTonAccount?.publicKey, publicKey)
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(restored.metaId)), Data(phrase.utf8))
        XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(fixture.wallet.metaId)), Data(phrase.utf8))
        XCTAssertFalse(fixture.wallet.hasBackup)
        navigation.popViewController(animated: false)
        await waitUntil { fixture.presenter.exportDatas == nil }
        UIPasteboard.general.string = "public sentinel after Back"
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "public sentinel after Back")
    }

    func testEveryHistoricalSpacingVariantCopiesAndReimportsItsOriginalIdentity() async throws {
        // Exact public outputs of released 4.0.4 factory: IC07 historical-state.json.
        let canonical = LegacyNativeTonFixture.phrase
        let cases: [(phrase: String, address: String, publicKey: String)] = [
            (phrase, address, publicKey.toHex()),
            (canonical + " ", "UQCzKbSV4o5EZJ1V0Ld9VpWUAwyLfNv4gyx00SeEFg1rtZEY", "f14148c55ccec237ef9d9f23b42e7e76faf019814c5001326433c7e64c09abcb"),
            (" " + canonical, "UQDOGZbd-5sN775xG9AiCozK4jM5lpdLfj_khrp9NAc4Nm50", "b9588e31c14c27cb4826927f2b8a0a0037823e7c619391bfc1435aa5d73930c7"),
            (canonical.replacingOccurrences(of: "replace imitate", with: "replace\nimitate"), "UQCUK6IuxFKqWmDLauEd_NAekoFIF0Wk0ZtgCReipRp_qY5N", "b16e6d3125e0112bd863148b12cf978beb31d6a54bb21998fea1a0d6cf8eebef"),
            (phrase.replacingOccurrences(of: "click mix", with: "click  mix") + " ", "UQDAvPv3OlQQnILPvED5YznIIVJVsbyhpsTNHfuOIh6jDv9q", "3a549170be054e76b1dec7ec3f8e64724f1946d9681eeb8038176a9744598c1f")
        ]
        for item in cases {
            let fixture = try fixture(irregular: true, historical: item)
            let (window, _) = try host(fixture.controller)
            defer { window.isHidden = true; window.rootViewController = nil; UIPasteboard.general.items = [] }
            try await closeWarning(fixture.controller, window: window)
            await waitUntil { fixture.presenter.exportDatas?.count == 1 }
            let copy = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-export-copy-exact" })
            reveal(copy, in: window); copy.sendActions(for: .touchUpInside)
            let copied = try XCTUnwrap(UIPasteboard.general.string)
            XCTAssertEqual(Data(copied.utf8), Data(item.phrase.utf8))
            let selected = try XCTUnwrap(LegacyTonMnemonic.importCandidates(copied).first { $0.publicKey.toHex() == item.publicKey })
            XCTAssertEqual(selected.address, item.address)
            let operation = MetaAccountOperationFactory(keystore: fixture.keys).newMetaAccountOperation(request:
                MetaAccountImportMnemonicRequest(mnemonic: selected.mnemonic, username: "Public exact restore",
                    substrateDerivationPath: "", ethereumDerivationPath: "", cryptoType: .ed25519, defaultChainId: "-239"), isBackuped: false)
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            let restored = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            XCTAssertEqual(restored.legacyTonAccount?.publicKey.toHex(), item.publicKey)
            XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(restored.metaId)), Data(item.phrase.utf8))
            XCTAssertEqual(try fixture.keys.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(fixture.wallet.metaId)), Data(item.phrase.utf8))
            XCTAssertFalse(fixture.wallet.hasBackup)
        }
    }

    func testExactCopyExpiresFromActualSystemPasteboard() async throws {
        let fixture = try fixture(irregular: true)
        let (window, _) = try host(fixture.controller)
        var copiedChangeCount: Int?
        defer {
            window.isHidden = true; window.rootViewController = nil
            if UIPasteboard.general.changeCount == copiedChangeCount { UIPasteboard.general.items = [] }
        }
        try await closeWarning(fixture.controller, window: window)
        await waitUntil { fixture.presenter.exportDatas?.count == 1 }
        let copy = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-export-copy-exact" })
        reveal(copy, in: window); copy.sendActions(for: .touchUpInside)
        copiedChangeCount = UIPasteboard.general.changeCount
        let started = Date()
        XCTAssertEqual(UIPasteboard.general.string, phrase)
        try await Task.sleep(nanoseconds: 61_000_000_000)
        let metadataHasStrings = UIPasteboard.general.hasStrings
        let finalChangeCount = UIPasteboard.general.changeCount
        let actualString = UIPasteboard.general.string
        let observation: [String: Any] = [
            "elapsedSeconds": Date().timeIntervalSince(started), "copiedChangeCount": copiedChangeCount ?? -1,
            "finalChangeCount": finalChangeCount, "hasStringsBeforeDataRead": metadataHasStrings,
            "hasStringsAfterDataRead": UIPasteboard.general.hasStrings, "actualStringPresent": actualString != nil,
            "originalPublicPhraseStillReadable": actualString == phrase,
            "actualStringSha256": actualString.map { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() } ?? ""
        ]
        let data = try JSONSerialization.data(withJSONObject: observation, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "exact-copy-expiry-observation"; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["TON_EXPORT_EVIDENCE_DIR"] {
            let url = URL(fileURLWithPath: directory); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try data.write(to: url.appendingPathComponent("expiry-observation.json"))
        }
        XCTAssertNotEqual(actualString, phrase, "The actual public phrase must no longer be readable")
        XCTAssertFalse(metadataHasStrings, "The copied public fixture must expire without another clipboard write")
    }

    func testActualExactCopyWarningAndTextFitAtNormalAndAccessibilitySizes() async throws {
        for language in ["en", "ru", "zh-Hans"] {
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let fixture = try fixture(irregular: true, language: language)
                let (window, _) = try host(fixture.controller, category: category)
                defer { window.isHidden = true; window.rootViewController = nil; UIPasteboard.general.items = [] }
                try await closeWarning(fixture.controller, window: window)
                await waitUntil { fixture.presenter.exportDatas?.count == 1 }
                window.layoutIfNeeded()
                let warning = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UILabel }.first { $0.accessibilityIdentifier == "ton-export-spacing-warning" })
                let text = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UILabel }.first { $0.accessibilityIdentifier == "ton-export-exact-text" })
                XCTAssertEqual(warning.text, R.string.localizable.exportTonExactWarning(preferredLanguages: [language]))
                XCTAssertEqual(text.text, phrase)
                for label in [warning, text] {
                    let expected = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertLessThanOrEqual(expected.height, label.bounds.height + 1)
                    XCTAssertLessThanOrEqual(label.bounds.width, 288)
                    if let scroll = descendants(fixture.controller.view).compactMap({ $0 as? UIScrollView }).first {
                        scroll.setContentOffset(CGPoint(x: 0, y: max(0, label.convert(label.bounds, to: scroll).minY - 12)), animated: false)
                    }
                    capture(window, "exact-\(language)-\(category.rawValue)-\(label.accessibilityIdentifier ?? "text")")
                }
                let copy = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UIControl }.first { $0.accessibilityIdentifier == "ton-export-copy-exact" })
                reveal(copy, in: window)
                capture(window, "copy-\(language)-\(category.rawValue)")
                copy.sendActions(for: .touchUpInside)
                XCTAssertEqual(UIPasteboard.general.string, phrase)
            }
        }
    }

    private func host(_ controller: UIViewController, category: UIContentSizeCategory = .large) throws -> (UIWindow, UINavigationController) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        let navigation = FearlessNavigationController(rootViewController: UIViewController())
        navigation.setViewControllers([navigation.viewControllers[0], controller], animated: false)
        window.rootViewController = navigation; window.makeKeyAndVisible(); window.layoutIfNeeded()
        return (window, navigation)
    }

    private func closeWarning(_ controller: UIViewController, window: UIWindow) async throws {
        await waitUntil { controller.presentedViewController is SheetAletViewController && controller.presentedViewController?.isBeingPresented == false }
        let sheet = try XCTUnwrap(controller.presentedViewController)
        let proceed = try XCTUnwrap(descendants(sheet.view).compactMap { $0 as? TriangularedButton }.first)
        reveal(proceed, in: window); proceed.sendActions(for: .touchUpInside)
        await waitUntil { controller.presentedViewController == nil }
    }

    private func reveal(_ view: UIView, in window: UIWindow) {
        var ancestor = view.superview
        while let next = ancestor {
            if let scroll = next as? UIScrollView { scroll.scrollRectToVisible(view.convert(view.bounds, to: scroll), animated: false); break }
            ancestor = next.superview
        }
        window.layoutIfNeeded()
        let frame = view.convert(view.bounds, to: window)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === view || hit?.isDescendant(of: view) == true)
    }
    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 { if condition() { return }; try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTFail("Actual native TON export did not settle")
    }
    private func capture(_ window: UIWindow, _ name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        if let directory = ProcessInfo.processInfo.environment["TON_EXPORT_EVIDENCE_DIR"] {
            let url = URL(fileURLWithPath: directory); try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try? image.pngData()?.write(to: url.appendingPathComponent(name + ".png"))
        }
    }
}
