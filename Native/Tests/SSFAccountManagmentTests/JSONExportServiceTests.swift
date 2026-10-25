import MocksBasket
import SSFModels
import XCTest

@testable import SSFAccountManagment

final class JSONExportServiceTests: XCTestCase {
    var service: JSONExportServiceProtocol?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let genesisService = GenesisBlockHashWorkerProtocolMock()
        genesisService.getGenesisHashReturnValue = "123"

        let fileURL = URL(string: "https://github.com")!
        let data = JSONExportData(
            data: "test",
            chain: TestData.chain,
            cryptoType: nil,
            fileURL: fileURL
        )
        let factory = JSONExportDataFactoryProtocolMock()
        factory
            .createJSONExportDataMetaIdAccountIdChainAccountChainPasswordAddressGenesisHashReturnValue =
            data

        service = JSONExportService(
            genesisService: genesisService,
            factory: factory
        )
    }

    override func tearDown() {
        super.tearDown()
        service = nil
    }

    func testExportWallet() async {
        // arrange
        let account = ChainAccountInfo(chain: TestData.chain, account: TestData.response)

        // act
        let data = await service?.export(
            wallet: TestData.account,
            accounts: [account],
            password: "123"
        )

        // assert
        XCTAssertNotNil(data)
    }

    func testExportAccount() async throws {
        // act
        let data = try await service?.exportAccount(
            address: "77TsMPwQq1UjycY3xZ5AJGRfCTjYS6hR7JypCsC7gUjsQSe",
            password: "123",
            chain: TestData.chain,
            wallet: TestData.account
        )

        // assert
        XCTAssertNotNil(data)
    }
}

extension JSONExportServiceTests {
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
