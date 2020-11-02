import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanLocalSearchEngine: InvoiceLocalSearchEngineProtocol {
    let networkType: SNAddressType

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType) {
        self.networkType = networkType
    }

    func searchByAccountId(_ accountId: String) -> SearchData? {
        guard let accountIdData = try? Data(hexString: accountId),
              accountIdData.count == ExtrinsicConstants.accountIdLength else {
            return nil
        }

        guard let address = try? addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: accountIdData),
                                                        type: networkType) else {
            return nil
        }

        let context = ContactContext(destination: .local)
        return SearchData(accountId: accountId, firstName: address, lastName: "", context: context.toContext())
    }
}
