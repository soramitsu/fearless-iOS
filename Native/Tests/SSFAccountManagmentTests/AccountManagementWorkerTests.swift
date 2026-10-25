import RobinHood
import SSFAccountManagmentStorage
import SSFHelpers
import SSFModels
import SSFUtils
import XCTest

@testable import SSFAccountManagment

final class AccountManagementWorkerTests: XCTestCase {
    var worker: AccountManagementWorkerProtocol?

    override func setUp() {
        super.setUp()
        let storageFacade = AccountStorageTestFacade()
        let metaAccountRepository = prepareMetaAccountRepository(storageFacade: storageFacade)
        let managedAccountRepository =
            prepareManagedMetaAccountRepository(storageFacade: storageFacade)
        let operationQueue = OperationQueue()

        worker = AccountManagementWorker(
            metaAccountRepository: metaAccountRepository,
            managedAccountRepository: managedAccountRepository,
            operationQueue: operationQueue
        )
    }

    override func tearDown() {
        super.tearDown()
        worker = nil
    }

    func testSaveAccount() throws {
        // act
        let managedAccount = ManagedMetaAccountModel(info: TestData.newAccount)
        worker?.save(account: managedAccount, completion: { [weak self] in
            Task { [weak self] in
                let result = try await self?.worker?.fetchAll()

                DispatchQueue.main.async {
                    XCTAssertEqual(result?.last?.name, TestData.newAccount.name)
                }
            }
        })
    }

    func testDeleteAllAccounts() async throws {
        // act
        worker?.deleteAll(completion: { [weak self] in
            Task { [weak self] in
                let result = try await self?.worker?.fetchAll()
                XCTAssertEqual(result, [])
            }
        })
    }
}

private extension AccountManagementWorkerTests {
    enum TestData {
        static let newAccount = AccountGenerator.generateMetaAccount()
        static let managedNewAccount = ManagedMetaAccountModel(
            info: TestData.account,
            isSelected: false,
            order: 2,
            balance: nil
        )

        static let account = MetaAccountModel(
            metaId: "1",
            name: "test",
            substrateAccountId: Data(),
            substrateCryptoType: 1,
            substratePublicKey: Data(),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            zeroBalanceAssetsHidden: true,
            hasBackup: false,
            favouriteChainIds: []
        )
    }

    func prepareMetaAccountRepository(storageFacade: StorageFacadeProtocol)
        -> AnyDataProviderRepository<MetaAccountModel>
    {
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let repository: AnyDataProviderRepository<MetaAccountModel> = accountRepositoryFactory
            .createMetaAccountRepository(
                for: nil,
                sortDescriptors: []
            )

        return repository
    }

    func prepareManagedMetaAccountRepository(storageFacade: StorageFacadeProtocol)
        -> AnyDataProviderRepository<ManagedMetaAccountModel>
    {
        let account = ManagedMetaAccountModel(info: TestData.account)

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: storageFacade)
        let repository: AnyDataProviderRepository<ManagedMetaAccountModel> =
            accountRepositoryFactory.createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: []
            )

        let saveOperation = repository.saveOperation({ [account] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        return repository
    }
}
