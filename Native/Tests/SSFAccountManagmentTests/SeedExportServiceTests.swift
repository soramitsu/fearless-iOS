import MocksBasket
import RobinHood
import SSFModels
import XCTest

@testable import SSFAccountManagment

final class SeedExportServiceTests: XCTestCase {
    var service: SeedExportService?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let seedData = SeedExportData(
            seed: Data(),
            derivationPath: nil,
            chain: TestData.chain,
            cryptoType: .ecdsa
        )

        let seedFactory = SeedExportDataFactoryProtocolMock()
        seedFactory.createSeedExportDataMetaIdAccountIdCryptoTypeChainReturnValue = seedData
        let operationManager = OperationManager()

        service = SeedExportService(
            seedFactory: seedFactory,
            operationManager: operationManager
        )
    }

    override func tearDown() {
        super.tearDown()
        service = nil
    }

    func testFetchExportDataForAddress() throws {
        // act
        let data = try service?.fetchExportDataFor(
            address: "77TsMPwQq1UjycY3xZ5AJGRfCTjYS6hR7JypCsC7gUjsQSe",
            chain: TestData.chain,
            wallet: TestData.account
        )

        // assert
        XCTAssertNotNil(data)
    }

    func testfetchExportDataForWallet() {
        // arrange
        let account = ChainAccountInfo(chain: TestData.chain, account: TestData.response)

        // act
        let data = service?.fetchExportDataFor(
            wallet: TestData.account,
            accounts: [account]
        )

        // assert
        XCTAssertNotNil(data)
    }
}

extension SeedExportServiceTests {
    enum TestData {
        static let chainAccount = ChainAccountModel(
            chainId: "Kusama",
            accountId: Data(),
            publicKey: Data(),
            cryptoType: 23,
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
            chainAccounts: [TestData.chainAccount],
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

        static let chain = ChainModel(
            rank: 1,
            disabled: true,
            chainId: "Kusama",
            parentId: "2",
            paraId: "test",
            name: "test",
            assets: [],
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

        static let response = ChainAccountResponse(
            chainId: TestData.chain.chainId,
            accountId: Data(),
            publicKey: Data(),
            name: "test",
            cryptoType: .ecdsa,
            addressPrefix: 1,
            isEthereumBased: false,
            isChainAccount: true,
            walletId: ""
        )
    }
}
