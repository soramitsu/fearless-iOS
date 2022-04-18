import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanLocalSearchEngine: InvoiceLocalSearchEngineProtocol {
    let chainFormat: ChainFormat

    init(chainFormat: ChainFormat) {
        self.chainFormat = chainFormat
    }

    func searchByAccountId(_ accountIdHex: String) -> SearchData? {
        guard let accountId = AccountId.matchHex(accountIdHex) else {
            return nil
        }

        guard let address = try? AddressFactory.address(
            for: accountId,
            chainFormat: chainFormat
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
