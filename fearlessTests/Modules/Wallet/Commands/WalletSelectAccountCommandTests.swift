import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class WalletSelectAccountCommandTests: XCTestCase {
    func testSelectAccount() throws {
        // given

        let commandFactory = WalletCommandFactoryProtocolMock()

        // when

        let command = WalletSelectAccountCommand(commandFactory: commandFactory)

        let completionExpectation = XCTestExpectation()

        commandFactory.presentationClosure = { _ in
            completionExpectation.fulfill()

            return WalletPresentationCommandProtocolMock()
        }

        try command.execute()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}
