import XCTest
import UIKit
import SoraFoundation
@testable import fearless

/// The export routes ask for the PIN first; the PIN screen is answered through
/// `showAuthorizationCompletion(with:)`, as the screen-authorization module does.
final class CovJBkBackupWalletRouterTests: XCTestCase {
    private func flow(_ wallet: MetaAccountModel) -> ExportFlow {
        .multiple(wallet: wallet, accounts: [])
    }

    /// Waits for the PIN screen to finish appearing; UIKit ignores a dismissal started mid-presentation.
    private func waitForPin(on host: CovJHostedView, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(CovJWait.until { host.presented?.viewIfLoaded?.window != nil }, file: file, line: line)
        CovJWait.drain(0.6)
        XCTAssertTrue(host.presented is PinSetupViewProtocol, file: file, line: line)
    }

    private func answerPin(_ authorized: Bool, router: BackupWalletRouter, host: CovJHostedView) {
        router.showAuthorizationCompletion(with: authorized)
        XCTAssertTrue(CovJWait.until(timeout: 3) { host.presented == nil })
        CovJWait.drain(0.1)
    }

    func testRefusedAuthorizationOpensNoExport() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let wallet = CovJBkFixture.wallet()
        let router = BackupWalletRouter()
        let routes: [() -> Void] = [
            { router.showMnemonicExport(flow: self.flow(wallet), from: host) },
            { router.showSeedExport(flow: self.flow(wallet), from: host) },
            { router.showKeystoreExport(flow: self.flow(wallet), from: host) },
            {
                router.showCreatePassword(
                    wallet: wallet, accounts: [], options: [.keystore], from: host, moduleOutput: nil
                )
            }
        ]

        for route in routes {
            route()
            waitForPin(on: host)
            answerPin(false, router: router, host: host)
            XCTAssertEqual(host.navigation.viewControllers.count, 1)
        }
    }

    func testRoutesWithoutAViewAskForNothing() {
        let router = BackupWalletRouter()
        let wallet = CovJBkFixture.wallet()
        var answers: [Bool] = []

        router.showMnemonicExport(flow: flow(wallet), from: nil)
        router.authorize(animated: false, cancellable: true, from: nil) { answers.append($0) }

        XCTAssertTrue(answers.isEmpty, "Without a screen to present on no PIN is requested")
        router.showAuthorizationCompletion(with: true)
        XCTAssertTrue(answers.isEmpty)
    }

    func testWalletDetailsArePushedWithoutAuthorization() throws {
        let host = try CovJHostedView()
        defer { host.close() }

        BackupWalletRouter().showWalletDetails(wallet: CovJBkFixture.wallet(), from: host)

        XCTAssertTrue(host.top is WalletDetailsViewController)
        XCTAssertNil(host.presented)
    }
}
