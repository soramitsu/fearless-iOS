import XCTest
@testable import fearless
import SoraKeystore
import RobinHood
import Cuckoo
import SoraFoundation

class WalletSelectAccountCommandTests: XCTestCase {
    func testSelectAccount() throws {
        // given

        let facade = UserDataStorageTestFacade()

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let seed1 = Data(repeating: 0, count: 32)
        let seed2 = Data(repeating: 1, count: 32)

        try AccountCreationHelper.createAccountFromSeed(seed1.toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let account1 = settings.selectedAccount!

        try AccountCreationHelper.createAccountFromSeed(seed2.toHex(),
                                                        cryptoType: .sr25519,
                                                        keychain: keychain,
                                                        settings: settings)

        let account2 = settings.selectedAccount!

        let accountsRepository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()
        let operation = accountsRepository.saveOperation({ [account1, account2]}, { [] })

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        let repositoryFactory = MockAccountRepositoryFactoryProtocol()

        stub(repositoryFactory) { stub in
            when(stub).createAccountRepsitory(for: any())
                .thenReturn(AnyDataProviderRepository(accountsRepository))
            when(stub).operationManager.get.thenReturn(OperationManager())
        }

        let commandFactory = WalletCommandFactoryProtocolMock()

        let eventCenter = MockEventCenterProtocol()

        // when

        let command = WalletSelectAccountCommand(repositoryFactory: repositoryFactory,
                                                 commandFactory: commandFactory,
                                                 settings: settings,
                                                 eventCenter: eventCenter,
                                                 localizationManager: LocalizationManager.shared)

        let completionExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            when(stub).notify(with: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        commandFactory.presentationClosure = { _ in
            command.modalPickerDidSelectModelAtIndex(0, context: [account1, account2] as NSArray)

            return WalletPresentationCommandProtocolMock()
        }

        try command.execute()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(settings.selectedAccount, account1)
    }
}
