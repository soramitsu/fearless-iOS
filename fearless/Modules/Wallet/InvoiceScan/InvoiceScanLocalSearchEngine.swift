import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanLocalSearchEngine: InvoiceLocalSearchEngineProtocol {
    let networkType: SNAddressType

    private lazy var addressFactory = SS58AddressFactory()

    init(networkType: SNAddressType) {
        self.networkType = networkType
    }

    func searchByAccountId(_ accountIdHex: String) -> SearchData? {
        guard let accountId = AccountId.matchHex(accountIdHex) else {
            return nil
        }

        guard let address = try? addressFactory
            .addressFromAccountId(data: accountId, type: networkType) else {
            return nil
        }

        let context = ContactContext(destination: .local)
        return SearchData(
            accountId: accountIdHex,
            firstName: address,
            lastName: "",
            context: context.toContext()
        )
    }
}
