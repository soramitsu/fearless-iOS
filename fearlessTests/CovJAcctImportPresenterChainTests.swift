import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
import UniformTypeIdentifiers
@testable import fearless

/// Per-network (chain) imports, the JSON upload sheet, the document picker and derivation-path errors.
final class CovJAcctImportPresenterChainTests: XCTestCase {
    private typealias Harness = CovJAcctImportHarness

    private let wallet = AccountGenerator.generateMetaAccount().replacingName("Vault")

    private func chainFlow(ethereum: Bool = false) -> (AccountImportFlow, ChainModel) {
        let chain = CovJFixture.chain(
            name: ethereum ? "Moonbeam" : "Kusama",
            icon: URL(string: "https://example.invalid/kusama.svg"),
            options: ethereum ? [.ethereumBased] : nil,
            addressPrefix: ethereum ? 1284 : 2
        )
        return (.chain(model: UniqueChainModel(meta: wallet, chain: chain)), chain)
    }

    private func loadChain(_ harness: Harness, _ source: AccountImportSource, value: String) {
        harness.presenter.didReceiveAccountImport(metadata: Harness.metadata(source))
        harness.presenter.sourceViewModel?.inputHandler.changeValue(to: value)
    }

    func testSubstrateChainSetupShowsNetworkAndHidesName() throws {
        let (flow, chain) = chainFlow()
        let harness = try Harness.make(flow: flow)
        defer { harness.close() }

        harness.presenter.setup()
        loadChain(harness, .mnemonic, value: Harness.phrase)

        XCTAssertEqual(harness.interactor.setups, 1)
        XCTAssertEqual(harness.view.uniqueChain?.text, chain.name)
        XCTAssertNotNil(harness.view.uniqueChain?.icon)
        XCTAssertEqual(harness.view.nameVisible, false)
        XCTAssertEqual(harness.presenter.usernameViewModel?.inputHandler.value, "Vault")
        XCTAssertEqual(harness.view.sources.last?.1, .substrate)
        XCTAssertEqual(harness.view.sources.last?.2, true)
        XCTAssertEqual(harness.view.chainTypes.last, .substrate)
        XCTAssertNotNil(harness.presenter.substrateDerivationPathViewModel)
        XCTAssertNil(harness.presenter.ethereumDerivationPathViewModel)
        XCTAssertEqual(harness.presenter.metadata?.availableSources.contains(.legacyTonMnemonic), false)
    }

    func testSubstrateChainMnemonicWithNonAsciiPasswordAsksAndImportsChosenAccount() throws {
        let (flow, chain) = chainFlow()
        let harness = try Harness.make(flow: flow)
        defer { harness.close() }
        loadChain(harness, .mnemonic, value: Harness.phrase)
        harness.presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//1///\u{E9}")

        harness.presenter.proceed()

        XCTAssertTrue(harness.interactor.chainRequests.isEmpty)
        let alert = try XCTUnwrap(harness.router.alerts.last)
        XCTAssertEqual(alert.actions.count, 2)
        let lines = alert.message?.components(separatedBy: "\n\n") ?? []
        XCTAssertEqual(lines.count, 3)

        alert.actions[1].handler?()

        let request = try XCTUnwrap(harness.interactor.chainRequests.first)
        XCTAssertEqual(request.chain.chainId, chain.chainId)
        XCTAssertEqual(request.meta.metaId, wallet.metaId)
        XCTAssertEqual(request.username, "Vault")
        XCTAssertEqual(request.cryptoType, .sr25519)
        guard case let .mnemonic(data) = request.source else { return XCTFail("Expected a mnemonic request") }
        XCTAssertEqual(data.substratePasswordRule, .nfc)
        XCTAssertEqual(data.derivationPath, "//1///\u{E9}")
        XCTAssertEqual(data.mnemonic.toString(), Harness.phrase)

        harness.presenter.didCompleteAccountImport()
        XCTAssertEqual(harness.router.proceeds.count, 1)
        guard case .chain? = harness.router.proceeds.first else { return XCTFail("Expected the chain flow") }
    }

    func testEthereumChainMnemonicUsesEcdsaAndDefaultEthereumPath() throws {
        let (flow, chain) = chainFlow(ethereum: true)
        let harness = try Harness.make(flow: flow)
        defer { harness.close() }
        loadChain(harness, .mnemonic, value: Harness.phrase)

        XCTAssertEqual(harness.view.chainTypes.last, .ethereum)
        harness.presenter.proceed()

        XCTAssertTrue(harness.router.alerts.isEmpty)
        let request = try XCTUnwrap(harness.interactor.chainRequests.first)
        XCTAssertEqual(request.chain.chainId, chain.chainId)
        XCTAssertEqual(request.cryptoType, .ecdsa)
        guard case let .mnemonic(data) = request.source else { return XCTFail("Expected a mnemonic request") }
        XCTAssertEqual(data.derivationPath, DerivationPathConstants.defaultEthereum)
        XCTAssertEqual(data.substratePasswordRule, .nfkd)
    }

    func testSubstrateChainSeedAndKeystoreImports() throws {
        let (flow, _) = chainFlow()
        let seedHarness = try Harness.make(flow: flow)
        defer { seedHarness.close() }
        loadChain(seedHarness, .seed, value: Harness.seed)
        seedHarness.presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: "//7")
        seedHarness.presenter.proceed()

        let seedRequest = try XCTUnwrap(seedHarness.interactor.chainRequests.first)
        guard case let .seed(seed) = seedRequest.source else { return XCTFail("Expected a seed request") }
        XCTAssertEqual(seed.seed, Harness.seed)
        XCTAssertEqual(seed.derivationPath, "//7")
        XCTAssertTrue(seedHarness.router.alerts.isEmpty, "A network import never asks to add Ethereum")

        let keystoreHarness = try Harness.make(flow: flow)
        defer { keystoreHarness.close() }
        loadChain(keystoreHarness, .keystore, value: "{\"address\":\"x\"}")
        keystoreHarness.presenter.passwordViewModel?.inputHandler.changeValue(to: "pw")
        keystoreHarness.presenter.proceed()

        let keystoreRequest = try XCTUnwrap(keystoreHarness.interactor.chainRequests.first)
        guard case let .keystore(keystore) = keystoreRequest.source else { return XCTFail("Expected a keystore request") }
        XCTAssertEqual(keystore.keystore, "{\"address\":\"x\"}")
        XCTAssertEqual(keystore.password, "pw")
    }

    func testChainMnemonicWithBadChecksumReportsFormatError() throws {
        let (flow, _) = chainFlow()
        let harness = try Harness.make(flow: flow)
        defer { harness.close() }
        loadChain(harness, .mnemonic, value: Array(repeating: "abandon", count: 12).joined(separator: " "))

        harness.presenter.proceed()

        XCTAssertTrue(harness.interactor.chainRequests.isEmpty)
        XCTAssertEqual(harness.router.errors.first as? AccountCreateError, .invalidMnemonicFormat)
    }

    func testUnhostedPresenterIgnoresUserActions() throws {
        let harness = try Harness.make(hosted: false)
        harness.load(.keystore, value: "{\"a\":1}")

        harness.presenter.activateUpload()
        harness.presenter.selectSourceType()
        harness.presenter.selectCryptoType()
        harness.presenter.proceed()

        XCTAssertTrue(harness.router.alerts.isEmpty)
        XCTAssertTrue(harness.router.errors.isEmpty)
        XCTAssertTrue(harness.interactor.metaRequests.isEmpty)
    }

    func testUploadSheetOffersPasteAndFileSelection() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.keystore, value: "")

        harness.presenter.activateUpload()

        let alert = try XCTUnwrap(harness.router.alerts.last)
        let languages = Harness.locale.rLanguages
        XCTAssertEqual(alert.title, R.string.localizable.importRecoveryJson(preferredLanguages: languages))
        XCTAssertNil(alert.message)
        XCTAssertEqual(alert.closeAction, R.string.localizable.commonCancel(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.map(\.title), [
            R.string.localizable.accountImportRecoveryJsonPlaceholder(preferredLanguages: languages),
            R.string.localizable.accountImportRecoverySelectFile(preferredLanguages: languages)
        ])

        alert.actions[1].handler?()

        XCTAssertEqual(harness.router.filePickers.count, 1)
        XCTAssertEqual(harness.router.filePickers.first, [.json])
    }

    func testDocumentPickerReadsJsonOrShowsInvalidFileAlert() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("covj-acct-\(UUID().uuidString).json")
        let json = "{\"encoded\":\"abc\"}"
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        harness.presenter.documentPicker(picker, didPickDocumentAt: url)
        XCTAssertEqual(harness.interactor.keystores, [json])

        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("covj-acct-missing-\(UUID().uuidString).json")
        harness.presenter.documentPicker(picker, didPickDocumentAt: missing)

        XCTAssertEqual(harness.interactor.keystores.count, 1)
        let alert = try XCTUnwrap(harness.router.alerts.last)
        let languages = Harness.locale.rLanguages
        XCTAssertEqual(alert.title, R.string.localizable.commonErrorGeneralTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.accountImportInvalidKeystore(preferredLanguages: languages))
        XCTAssertEqual(alert.actions.map(\.title), [R.string.localizable.commonOk(preferredLanguages: languages)])
    }

    func testInvalidDerivationPathsReportTheMatchingError() throws {
        let cases: [(AccountImportSource, CryptoType, String, String?, AccountCreationError)] = [
            (.seed, .sr25519, "///pwd", nil, .invalidDerivationHardSoft),
            (.seed, .ed25519, "/soft", nil, .invalidDerivationHard),
            (.seed, .ecdsa, "/soft", nil, .invalidDerivationHard),
            (.mnemonic, .ed25519, "/soft", nil, .invalidDerivationHardPassword),
            (.mnemonic, .ecdsa, "/soft", nil, .invalidDerivationHardPassword),
            (.mnemonic, .sr25519, "soft", nil, .invalidDerivationHardSoftPassword),
            (.mnemonic, .sr25519, "", "abc", .invalidDerivationHardSoftNumeric)
        ]
        for (source, crypto, substrate, ethereum, expected) in cases {
            let harness = try Harness.make()
            defer { harness.close() }
            harness.load(source, crypto: crypto, value: source == .seed ? Harness.seed : Harness.phrase)
            harness.presenter.substrateDerivationPathViewModel?.inputHandler.changeValue(to: substrate)
            if let ethereum {
                harness.presenter.ethereumDerivationPathViewModel?.inputHandler.changeValue(to: ethereum)
            }

            harness.presenter.proceed()

            let label = "\(source) \(crypto) \(substrate)"
            XCTAssertEqual(harness.router.errors.count, 1, label)
            XCTAssertEqual(harness.router.errors.first as? AccountCreationError, expected, label)
            if ethereum == nil {
                XCTAssertEqual(harness.view.substrateStatuses.last, .invalid, label)
            } else {
                XCTAssertEqual(harness.view.ethereumStatuses.last, .invalid, label)
            }
            XCTAssertTrue(harness.interactor.metaRequests.isEmpty, label)
            XCTAssertTrue(harness.router.alerts.isEmpty, label)
        }
    }

    func testUnprefixedAndEmptySeedsPassFormatValidation() throws {
        let harness = try Harness.make()
        defer { harness.close() }
        harness.load(.seed, value: String(repeating: "f", count: 64))
        harness.presenter.proceed()
        XCTAssertTrue(harness.router.errors.isEmpty)
        XCTAssertEqual(harness.router.alerts.count, 1, "A valid seed asks whether to add Ethereum")

        let empty = try Harness.make()
        defer { empty.close() }
        empty.load(.seed, value: "")
        empty.presenter.proceed()
        XCTAssertTrue(empty.router.errors.isEmpty, "An empty seed passes format validation")
        XCTAssertEqual(empty.router.alerts.count, 1)
    }
}
