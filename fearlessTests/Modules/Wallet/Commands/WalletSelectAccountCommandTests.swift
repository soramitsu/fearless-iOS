import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class WalletSelectAccountCommandTests: XCTestCase {
    func testSelectAccount() throws {
        // given

        final class TestFactory: fearless.WalletCommandFactoryProtocol {
            var onPrepare: ((UIViewController) -> Void)?
            func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand {
                let cmd = WalletPresentationCommand(presentingController: controller)
                // Invoke callback so test can fulfill expectation
                onPrepare?(controller)
                return cmd
            }
            func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand {
                WalletPresentationCommand()
            }
        }

        let commandFactory = TestFactory()

        // when

        let command = WalletSelectAccountCommand(commandFactory: commandFactory)

        let completionExpectation = XCTestExpectation()

        commandFactory.onPrepare = { _ in
            completionExpectation.fulfill()
        }

        try command.execute()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
