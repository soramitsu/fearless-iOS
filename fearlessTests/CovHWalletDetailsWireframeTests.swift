import XCTest
import UIKit
import SafariServices
import SSFModels
@testable import fearless

final class CovHWalletDetailsWireframeTests: XCTestCase {
    private let wireframe = WalletDetailsWireframe()
    private let host = CovHChainAccountWireframeHost()
    private var navigation: CovHChainAccountNavigationSpy!
    private let chain = CovHChainAccountFixture.chain()
    private let wallet = CovHChainAccountFixture.wallet()

    override func setUp() {
        super.setUp()
        navigation = CovHChainAccountNavigationSpy(rootViewController: host)
        navigation.isRecording = true
        XCTAssertTrue(host.navigationController === navigation)
    }

    func testPickersArePresentedOnlyForNonEmptyLists() {
        wireframe.presentActions(from: host, items: [], chain: chain) { _ in }
        wireframe.showUniqueChainSourceSelection(from: host, items: []) { _ in }
        XCTAssertTrue(host.presented.isEmpty)
        wireframe.presentActions(from: host, items: [.copyAddress, .export], chain: chain) { _ in }
        wireframe.showUniqueChainSourceSelection(from: host, items: ReplaceChainOption.allCases) { _ in }
        XCTAssertEqual(host.presented.count, 2)
        XCTAssertTrue(navigation.presented.isEmpty)
    }

    func testNodeSelectionAndExplorerArePresented() throws {
        wireframe.presentNodeSelection(from: host, chain: chain)
        XCTAssertTrue(host.presented.last is NodeSelectionViewController)
        let url = try XCTUnwrap(URL(string: "https://scan.invalid/account/cov"))
        wireframe.present(from: host, url: url)
        XCTAssertTrue(host.presented.last is SFSafariViewController)
        XCTAssertEqual(host.presented.count, 2)
    }

    func testCreateIsPushed() {
        wireframe.showCreate(uniqueChainModel: UniqueChainModel(meta: wallet, chain: chain), from: host)
        XCTAssertTrue(navigation.pushed.last is UsernameSetupViewController)
    }

    func testMissingAccountSheetOffersCreateImportAndSkip() throws {
        var skipped: [ChainModel] = []
        let locale = Locale(identifier: "en")
        wireframe.presentAccountOptions(
            from: host,
            locale: locale,
            options: [.create, .import, .skip],
            uniqueChainModel: UniqueChainModel(meta: wallet, chain: chain)
        ) { skipped.append($0) }
        let model = try XCTUnwrap(CovHChainAccountSheetReader.model(of: host.presented.last))
        XCTAssertEqual(model.title, R.string.localizable.importSourcePickerTitle(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.closeAction, R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(model.actions.map(\.title), [
            R.string.localizable.createNewAccount(preferredLanguages: locale.rLanguages),
            R.string.localizable.alreadyHaveAccount(preferredLanguages: locale.rLanguages),
            R.string.localizable.missingAccountSkip(preferredLanguages: locale.rLanguages)
        ])
        model.actions[2].handler?()
        XCTAssertEqual(skipped.map(\.chainId), [chain.chainId])
        model.actions[0].handler?()
        XCTAssertTrue(navigation.pushed.last is UsernameSetupViewController)
    }

    func testExportSheetAuthorizesEachOptionBeforePushingItsScreen() throws {
        wireframe.showExport(flow: .multiple(wallet: wallet, accounts: []), options: [.mnemonic, .keystore, .seed], locale: nil, from: host)
        let model = try XCTUnwrap(CovHChainAccountSheetReader.model(of: host.presented.last))
        XCTAssertEqual(model.actions.count, 3)
        XCTAssertNil(model.message)
        for action in model.actions {
            action.handler?()
            XCTAssertTrue(host.presented.last is PinSetupViewController)
            wireframe.showAuthorizationCompletion(with: true)
        }
        XCTAssertEqual(navigation.pushed.count, 3)
        XCTAssertTrue(navigation.pushed[0] is ExportGenericViewController)
        XCTAssertTrue(navigation.pushed[1] is AccountExportPasswordViewController)
        XCTAssertTrue(navigation.pushed[2] is ExportGenericViewController)

        model.actions[0].handler?()
        wireframe.showAuthorizationCompletion(with: false)
        XCTAssertEqual(navigation.pushed.count, 3, "a cancelled PIN exports nothing")
    }
}
