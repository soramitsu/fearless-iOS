import UIKit
import CommonWallet

final class WalletScanQRInteractor {
    weak var presenter: WalletScanQRInteractorOutputProtocol?
}

extension WalletScanQRInteractor: WalletScanQRInteractorInputProtocol {}
