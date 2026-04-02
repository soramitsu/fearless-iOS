import XCTest
@testable import fearless
import RobinHood

class SelectedAccountSettingsTests: XCTestCase {
    func testSelectFirst() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let selectedAccount = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
            isSelected: true
        )

        // when

        let setupExpectation = XCTestExpectation()
        selectedAccountSettings.setup(runningCompletionIn: .main) { _ in
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertNil(selectedAccountSettings.value)

        let saveExpectation = XCTestExpectation()
        selectedAccountSettings.save(value: selectedAccount.info, runningCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        // then

        XCTAssertEqual(selectedAccountSettings.value, selectedAccount.info)

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        XCTAssertEqual(selectedAccount.info, allMetaAccounts.first?.info)
        XCTAssertEqual(allMetaAccounts.count, 1)
        XCTAssertEqual(allMetaAccounts.first?.isSelected, true)
    }

    func testChangeSelectedAccount() throws {
        // given

        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let selectedAccountSettings = SelectedWalletSettings(
            storageFacade: facade,
            operationQueue: operationQueue
        )

        let mapper = ManagedMetaAccountMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))

        let initialSelectedAccount = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
            isSelected: true
        )

        let nextSelectedAccount = AccountGenerator.generateMetaAccount(generatingChainAccounts: 2)

        let saveOperation = repository.saveOperation({ [initialSelectedAccount] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // when

        let setupExpectation = XCTestExpectation()
        selectedAccountSettings.setup(runningCompletionIn: .main) { _ in
            setupExpectation.fulfill()
        }

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        XCTAssertEqual(selectedAccountSettings.value, initialSelectedAccount.info)

        let saveExpectation = XCTestExpectation()
        selectedAccountSettings.save(value: nextSelectedAccount, runningCompletionIn: .main) { _ in
            saveExpectation.fulfill()
        }

        wait(for: [saveExpectation], timeout: Constants.defaultExpectationDuration)

        // then

        XCTAssertEqual(selectedAccountSettings.value, nextSelectedAccount)

        let allMetaAccountsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )

        let expectedAccounts = [initialSelectedAccount.info, nextSelectedAccount].reduce(
            into: [String: fearless.MetaAccountModel]()
        ) { result, account in
            result[account.metaId] = account
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: fearless.MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        XCTAssertEqual(expectedAccounts, actualAccounts)
    }
}
