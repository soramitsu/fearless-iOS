import XCTest
import UIKit
import SSFModels
import IrohaCrypto
import SoraFoundation
@testable import fearless

final class CovJAcctOnboardingViewStub: UIViewController, OnboardingMainViewProtocol {
    var preinstalled: [Bool] = []
    var loads = 0
    func didReceive(preinstalledWalletEnabled: Bool) { preinstalled.append(preinstalledWalletEnabled) }
    func didStartLoading() { loads += 1 }
    func didStopLoading() { loads -= 1 }
}

final class CovJAcctConfirmRoutingTests: XCTestCase {
    func testOnboardingConfirmAndImportHandPinSetupToRootAnimator() throws {
        let confirm = AccountConfirmWireframe()
        let animator = CovJAcctRootAnimatorSpy()
        confirm.rootAnimator = animator

        confirm.proceed(from: nil, flow: try CovJAcctConfirmFixture.walletFlow())
        confirm.proceed(from: nil, flow: nil)
        confirm.proceed(from: nil, flow: try CovJAcctConfirmFixture.chainFlow())
        XCTAssertEqual(animator.controllers.count, 2)
        XCTAssertTrue(animator.controllers.allSatisfy { $0 is PinSetupViewProtocol })

        let importWireframe = AccountImportWireframe()
        let importAnimator = CovJAcctRootAnimatorSpy()
        importWireframe.rootAnimator = importAnimator
        importWireframe.proceed(from: nil, flow: .wallet(step: .substrate))
        XCTAssertEqual(importAnimator.controllers.count, 1)
        XCTAssertTrue(importAnimator.controllers.first is PinSetupViewProtocol)

        AddAccount.AccountConfirmWireframe().proceed(from: nil, flow: nil)
        XCTAssertEqual(animator.controllers.count, 2)
    }

    func testSwitchConfirmPopsToRoot() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let view = CovJAcctConfirmViewStub()
        host.navigation.pushViewController(UIViewController(), animated: false)
        host.navigation.pushViewController(view, animated: false)

        SwitchAccount.AccountConfirmWireframe().proceed(from: nil, flow: nil)
        XCTAssertEqual(host.navigation.viewControllers.count, 3)
        SwitchAccount.AccountConfirmWireframe().proceed(from: view, flow: nil)

        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })
    }

    func testConfirmFactoriesBuildNibControllers() throws {
        let flow = try CovJAcctConfirmFixture.walletFlow()
        let adding = try XCTUnwrap(AccountConfirmViewFactory.createViewForAdding(flow: flow))
        let switching = try XCTUnwrap(AccountConfirmViewFactory.createViewForSwitch(flow: try CovJAcctConfirmFixture.chainFlow()))
        let export = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            try CovJAcctConfirmFixture.mnemonic(), wallet: AccountGenerator.generateMetaAccount()
        ))
        for view in [adding, switching, export] {
            let controller = try XCTUnwrap(view.controller as? AccountConfirmViewController)
            XCTAssertNotNil(controller.presenter)
            XCTAssertFalse(controller.isViewLoaded)
        }
        let exportController = try XCTUnwrap(export.controller as? AccountConfirmViewController)
        XCTAssertFalse(exportController.showsExactMnemonicSpacing)
    }

    func testExportConfirmationShowsSuccessThenReturnsToRoot() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let view = CovJAcctConfirmViewStub()
        host.navigation.pushViewController(UIViewController(), animated: false)
        host.navigation.pushViewController(view, animated: false)

        ExportMnemonicConfirmWireframe(localizationManager: LocalizationManager.shared).proceed(from: view, flow: nil)

        XCTAssertNotNil(view.presentedViewController ?? host.navigation.presentedViewController)
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.navigation.viewControllers.count == 1 })
    }
}

final class CovJAcctExportRoutingTests: XCTestCase {
    private func stacked() throws -> (CovJHostedView, CovJAcctExportViewStub) {
        let host = try CovJHostedView()
        let view = CovJAcctExportViewStub()
        host.navigation.pushViewController(view, animated: false)
        return (host, view)
    }

    func testMnemonicWireframeOpensConfirmationAndGoesBack() throws {
        let wireframe = ExportMnemonicWireframe()
        let mnemonic = try CovJAcctConfirmFixture.mnemonic()
        let wallet = AccountGenerator.generateMetaAccount()

        let (host, view) = try stacked()
        defer { host.close() }
        wireframe.openConfirmationForMnemonic(mnemonic, wallet: wallet, from: view)
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.top is AccountConfirmViewController })

        let (proofHost, proofView) = try stacked()
        defer { proofHost.close() }
        wireframe.openConfirmationForMnemonic(mnemonic, wallet: wallet, backupProof: nil, from: proofView)
        XCTAssertTrue(CovJWait.until(timeout: 3) { proofHost.top is AccountConfirmViewController })

        let (backHost, backView) = try stacked()
        defer { backHost.close() }
        wireframe.back(view: backView)
        XCTAssertTrue(CovJWait.until { backHost.navigation.viewControllers.count == 1 })
    }

    func testRestoreJsonWireframePresentsActionsAndPops() throws {
        let wireframe = ExportRestoreJsonWireframe()

        let (pickerHost, pickerView) = try stacked()
        defer { pickerHost.close() }
        wireframe.presentExportActionsFlow(from: pickerView, items: [], callback: { _ in })
        XCTAssertNil(pickerHost.navigation.presentedViewController)
        wireframe.presentExportActionsFlow(from: pickerView, items: [.file, .text], callback: { _ in })
        XCTAssertNotNil(pickerHost.navigation.presentedViewController)

        let (passwordHost, passwordView) = try stacked()
        defer { passwordHost.close() }
        wireframe.showChangePassword(from: passwordView)
        XCTAssertTrue(CovJWait.until { passwordHost.navigation.viewControllers.count == 1 })

        let (backHost, backView) = try stacked()
        defer { backHost.close() }
        wireframe.back(view: backView)
        XCTAssertTrue(CovJWait.until { backHost.navigation.viewControllers.count == 1 })
    }

    func testExportViewFactoriesBuildGenericControllers() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let flow = ExportFlow.multiple(wallet: wallet, accounts: [])
        let seed = try XCTUnwrap(ExportSeedViewFactory.createViewForAddress(flow: flow))
        let mnemonic = try XCTUnwrap(ExportMnemonicViewFactory.createViewForAddress(flow: flow))
        for view in [seed, mnemonic] {
            let controller = try XCTUnwrap(view.controller as? ExportGenericViewController)
            XCTAssertFalse(controller.isViewLoaded)
            XCTAssertNotNil(controller.localizationManager)
        }
    }
}

final class CovJAcctOnboardingRoutingTests: XCTestCase {
    private func hosted() throws -> (CovJHostedView, CovJAcctOnboardingViewStub) {
        let view = CovJAcctOnboardingViewStub()
        return (try CovJHostedView(controller: view), view)
    }

    private func exercise(_ wireframe: OnboardingMainWireframeProtocol, name: String) throws {
        let (signupHost, signupView) = try hosted()
        defer { signupHost.close() }
        wireframe.showSignup(from: signupView)
        XCTAssertTrue(signupHost.top is UsernameSetupViewController, name)

        let (createHost, createView) = try hosted()
        defer { createHost.close() }
        wireframe.showCreateFlow(from: createView)
        XCTAssertEqual(createHost.navigation.viewControllers.count, 2, name)
        XCTAssertFalse(createHost.top === createView, name)

        try CovJAcctURLHandling.withKeystoreService {
            let (restoreHost, restoreView) = try hosted()
            defer { restoreHost.close() }
            wireframe.showAccountRestore(defaultSource: .seed, from: restoreView)
            XCTAssertTrue(restoreHost.top is AccountImportViewController, name)

            let (keystoreHost, keystoreView) = try hosted()
            defer { keystoreHost.close() }
            wireframe.showKeystoreImport(from: keystoreView)
            XCTAssertTrue(keystoreHost.top is AccountImportViewController, name)

            let (coveredHost, coveredView) = try hosted()
            defer { coveredHost.close() }
            coveredHost.navigation.pushViewController(UIViewController(), animated: false)
            wireframe.showKeystoreImport(from: coveredView)
            XCTAssertEqual(coveredHost.navigation.viewControllers.count, 2, name)
            XCTAssertFalse(coveredHost.top is AccountImportViewController, name)
        }
    }

    func testAddAndSwitchOnboardingWireframesPushEntryScreens() throws {
        try exercise(AddAccount.OnboardingMainWireframe(), name: "add")
        try exercise(SwitchAccount.OnboardingMainWireframe(), name: "switch")
    }
}
