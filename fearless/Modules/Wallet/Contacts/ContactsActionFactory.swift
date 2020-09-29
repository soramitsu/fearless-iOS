import Foundation
import CommonWallet

struct ContactsActionFactory: ContactsActionFactoryWrapperProtocol {
    func createBarActionForAccountId(_ accountId: String, assetId: String) -> WalletBarActionViewModelProtocol? {
        guard let qrIcon = R.image.iconScanQr() else {
            return nil
        }

        return WalletBarActionViewModel(displayType: .icon(qrIcon),
                                        command: StubCommandDecorator())
    }
}
