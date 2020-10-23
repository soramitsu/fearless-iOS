import Foundation
import CommonWallet

struct ContactsActionFactory: ContactsActionFactoryWrapperProtocol {
    func createOptionListForAccountId(_ accountId: String, assetId: String, locale: Locale?)
        -> [SendOptionViewModelProtocol]? {
        []
    }

    func createBarActionForAccountId(_ accountId: String, assetId: String) -> WalletBarActionViewModelProtocol? {
        nil
    }
}
