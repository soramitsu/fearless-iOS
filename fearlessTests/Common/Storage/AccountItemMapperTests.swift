import XCTest
@testable import fearless
import RobinHood
import IrohaCrypto

class AccountItemMapperTests: XCTestCase {
    func testSaveAndFetchItem() throws {
        // given
        let settings = SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(),
            operationQueue: OperationQueue()
        )

        // when
        let keypair = try SECKeyFactory().createRandomKeypair()
        let address = try SS58AddressFactory().address(fromPublicKey: keypair.publicKey(),
                                                       type: .kusamaMain)
        let accountId = try keypair.publicKey().rawData().publicKeyToAccountId()

        let metaAccountItem = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "metaAccount",
            substrateAccountId: accountId,
            substrateCryptoType: MultiassetCryptoType.substrateEcdsa.rawValue,
            substratePublicKey: keypair.publicKey().rawData(),
            ethereumAddress: address.asSecretData(),
            ethereumPublicKey: keypair.publicKey().rawData(),
            chainAccounts: []
        )

        settings.save(value: metaAccountItem)

        // then

        XCTAssertTrue(settings.hasValue)

        // when
        let receivedMetaAccountItem = settings.value

        // then
        XCTAssertEqual(metaAccountItem, receivedMetaAccountItem)
    }
}
