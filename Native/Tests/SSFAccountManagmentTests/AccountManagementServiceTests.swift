import MocksBasket
import RobinHood
import SSFAccountManagmentStorage
import SSFHelpers
import SSFModels
import SSFUtils
import XCTest

@testable import SSFAccountManagment

final class AccountManagementServiceTests: XCTestCase {
    var service: AccountManageble?
    var accountManagementWorker: AccountManagementWorkerProtocolMock?

    override func setUp() {
        super.setUp()
        let storageFacade = AccountStorageTestFacade()

        let accountManagementWorker = AccountManagementWorkerProtocolMock()
        accountManagementWorker.saveAccountCompletionClosure = { _, closure in
            closure()
        }
        self.accountManagementWorker = accountManagementWorker

        let selectedWallet = SelectedWalletSettings(storageFacade: storageFacade)

        service = AccountManagementService(
            accountManagementWorker: accountManagementWorker,
            selectedWallet: selectedWallet
        )
    }

    override func tearDown() {
        super.tearDown()
        service = nil
        accountManagementWorker = nil
    }

    func testGetCurrentAccountNoAccount() {
        // act
        let result = service?.getCurrentAccount()

        // assert
        XCTAssertNil(result)
    }

    func testSetCurrentAccount() throws {
        // act
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in
            let currentAccount = self?.service?.getCurrentAccount()

            // assert
            DispatchQueue.main.async {
                XCTAssertEqual(currentAccount, TestData.account)
            }
        })
    }

    func testUpdateVisability() throws {
        // arrange
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in

            // act
            let chain = TestData.chain
            let asset = TestData.asset

            let chainAsset = ChainAsset(chain: chain, asset: asset)

            do {
                try self?.service?.update(visible: true, for: chainAsset, completion: {
                    // assert
                    DispatchQueue.main.async {
                        XCTAssertTrue(
                            self?.accountManagementWorker?
                                .saveAccountCompletionCalled ?? false
                        )
                    }
                })
            } catch {
                XCTFail("UpdateVisability test failed with error - \(error)")
            }
        })
    }

    func testLogout() throws {
        // act
        service?.setCurrentAccount(account: TestData.account, completionClosure: { [weak self] _ in
            Task { [weak self] in
                try await self?.service?.logout()
                let currentAccount = self?.service?.getCurrentAccount()

                // assert
                XCTAssertNil(currentAccount)
            }
        })
    }
}

private extension AccountManagementServiceTests {
    enum TestData {
        static let chain = ChainModel(
            rank: 1,
            disabled: true,
            chainId: "Kusama",
            parentId: "2",
            paraId: "test",
            name: "test",
            assets: [asset],
            xcm: nil,
            nodes: [],
            addressPrefix: 1,
            types: nil,
            icon: nil,
            options: [.crowdloans, .ethereum, .testnet],
            externalApi: nil,
            selectedNode: nil,
            customNodes: [],
            iosMinAppVersion: nil,
            identityChain: nil
        )

        static let asset = AssetModel(
            id: "2",
            name: "test",
            symbol: "XOR",
            precision: 1,
            icon: nil,
            price: Decimal(integerLiteral: 1),
            fiatDayChange: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: false,
            isNative: false,
            staking: nil,
            purchaseProviders: nil,
            type: .assetId,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )

        static let chainAccounts = ChainAccountModel(
            chainId: "Kusama",
            accountId: Data(),
            publicKey: Data(),
            cryptoType: 2,
            ethereumBased: false
        )

        static let account = MetaAccountModel(
            metaId: "1",
            name: "test",
            substrateAccountId: Data(),
            substrateCryptoType: 1,
            substratePublicKey: Data(),
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccounts],
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
}
