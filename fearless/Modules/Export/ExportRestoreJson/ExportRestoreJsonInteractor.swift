import Foundation
import IrohaCrypto
import UIKit

final class ExportRestoreJsonInteractor {
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    init(
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
    }
}

extension ExportRestoreJsonInteractor: ExportRestoreJsonInteractorProtocol {
    func walletDidBackuped(completion: @escaping (Result<Void, Error>) -> Void) {
        let events = eventCenter
        settings.recordBackup(of: wallet) { result in
            if case let .success(savedWallet) = result {
                events.notify(with: MetaAccountModelChangedEvent(account: savedWallet))
            }
            completion(result.map { _ in () })
        }
    }
}
