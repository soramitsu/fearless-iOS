import IrohaCrypto
import MocksBasket
import RobinHood
import SoraKeystore
import SSFKeyPair
import SSFModels
import XCTest

@testable import SSFAccountManagment

final class AccountImportServiceTests: XCTestCase {
    var service: AccountImportable?
    var mnemonicCreator: MnemonicCreatorMock?

    override func setUpWithError() throws {
        try super.setUpWithError()

        let storageFacade = AccountStorageTestFacade()
        let operationManager = OperationManager()
        let selectedWallet = SelectedWalletSettings(storageFacade: storageFacade)
        let accountOperationFactory = MetaAccountOperationFactory(keystore: InMemoryKeychain())

        let mnemonicCreator = try setupMnemonicCreator()
        self.mnemonicCreator = mnemonicCreator

        service = AccountImportService(
            accountOperationFactory: accountOperationFactory,
            storageFacade: storageFacade,
            mnemonicCreator: mnemonicCreator,
            operationManager: operationManager,
            selectedWallet: selectedWallet
        )
    }

    override func tearDown() {
        super.tearDown()
        service = nil
        mnemonicCreator = nil
    }

    func testImportMetaAccountMnemonic() async throws {
        // arrange
        let data = MetaAccountImportRequestSource.MnemonicImportRequestData(
            mnemonic: TestData.mnemonicString,
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum
        )

        let source: MetaAccountImportRequestSource = .mnemonic(data: data)
        let request = MetaAccountImportRequest(
            source: source,
            username: TestData.accountName,
            cryptoType: .sr25519,
            defaultChainId: "5d3c298622d5634ed019bf61ea4b71655030015bde9beb0d6a24743714462c86"
        )

        // act
        let account = try await service?.importMetaAccount(request: request)

        // assert
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.name, TestData.accountName)
        XCTAssertEqual(mnemonicCreator?.mnemonicFromListCallsCount, 1)
    }

    func testImportMetaAccountSeed() async throws {
        // arrange
        let data = MetaAccountImportRequestSource.SeedImportRequestData(
            substrateSeed: "0xbf57a61b1d24b6cde5a12f6779e9d13f7c59db72fc2a63bd382a6c91e7e41f61",
            ethereumSeed: nil,
            substrateDerivationPath: "",
            ethereumDerivationPath: nil
        )
        let source: MetaAccountImportRequestSource = .seed(data: data)
        let request = MetaAccountImportRequest(
            source: source,
            username: TestData.accountName,
            cryptoType: .sr25519,
            defaultChainId: "5d3c298622d5634ed019bf61ea4b71655030015bde9beb0d6a24743714462c86"
        )

        // act
        let account = try await service?.importMetaAccount(request: request)

        // assert
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.name, TestData.accountName)
    }

    func testImportMetaAccountKey() async throws {
        // arrange
        let data = MetaAccountImportRequestSource.KeystoreImportRequestData(
            substrateKeystore: TestData.keystore,
            ethereumKeystore: nil,
            substratePassword: "test5",
            ethereumPassword: nil
        )
        let source: MetaAccountImportRequestSource = .keystore(data: data)
        let request = MetaAccountImportRequest(
            source: source,
            username: TestData.accountName,
            cryptoType: .sr25519,
            defaultChainId: "5d3c298622d5634ed019bf61ea4b71655030015bde9beb0d6a24743714462c86"
        )

        // act
        let account = try await service?.importMetaAccount(request: request)

        // assert
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.name, TestData.accountName)
    }
}

extension AccountImportServiceTests {
    enum TestData {
        static let mnemonicString =
            "street firm worth record skin taste legend lobster magnet stove drive side"

        static let accountName = "Test user 1"
        static let account = MetaAccountModel(
            metaId: "1",
            name: TestData.accountName,
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

        static let keystore = """
        {"address":"FMN7zMySGxiWrDuPDkf1jrGoF9szj9igADV8V9pXUwbzDwB","encoded":"iBuxjCbMpKPvEGfDOuoT0ysF97PrHUqD6doj9Zcf//QAgAAAAQAAAAgAAADcNAYEnNvLMxu1THSwps04uYmmYeutsA3yCWS70y+LRXyu8VUhCMtkY/30HOqnvvkm/dgR9s5ZFn/n+arKQ9RgtigWqNStt4JxQdb+bwuc/SRXuIO4JEf2dRZOsNtQusf+9zQwrWqLmQpX6EBHVS5E3RPxRBw0qRPygKe0i/T+dRPQntcU0AYhuGRswWE8TREY5gcynPJpx2l1OnGT","encoding":{"content":["pkcs8","sr25519"],"type":["scrypt","xsalsa20-poly1305"],"version":"3"},"meta":{"genesisHash":"0xb0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe","name":"Test5","tags":[],"whenCreated":1596785222977}}
        """
    }

    private func setupMnemonicCreator() throws -> MnemonicCreatorMock {
        let mnemonicCreator = MnemonicCreatorMock()
        let mnemonicText =
            "street firm worth record skin taste legend lobster magnet stove drive side"
        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicText)
        mnemonicCreator.mnemonicFromListReturnValue = mnemonic
        return mnemonicCreator
    }
}
