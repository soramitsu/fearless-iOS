import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanLocalSearchEngine: InvoiceLocalSearchEngineProtocol {
    let addressPrefix: UInt16

    private lazy var addressFactory = SS58AddressFactory()

    init(addressPrefix: UInt16) {
        self.addressPrefix = addressPrefix
    }

    func searchByAccountId(_ accountIdHex: String) -> SearchData? {
        guard let accountId = AccountId.matchHex(accountIdHex) else {
            return nil
        }

        guard let address = try? addressFactory
            .addressFromAccountId(
                data: accountId,
                addressPrefix: addressPrefix
            ) else {
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
