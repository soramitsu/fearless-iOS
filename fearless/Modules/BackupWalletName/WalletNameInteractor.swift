import UIKit
import RobinHood

protocol WalletNameInteractorOutput: AnyObject {
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>)
}

final class WalletNameInteractor {
    // MARK: - Private properties

    private weak var output: WalletNameInteractorOutput?

    private let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }
}

// MARK: - BackupWalletNameInteractorInput

extension WalletNameInteractor: WalletNameInteractorInput {
    func save(wallet: MetaAccountModel) {
        SelectedWalletSettings.shared.performSave(value: wallet) { [weak self] result in
            switch result {
            case let .success(account):
                self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                self?.eventCenter.notify(with: WalletNameChanged(wallet: account))
            case .failure:
                break
            }
            DispatchQueue.main.async {
                self?.output?.didReceiveSaveOperation(result: result)
            }
        }
    }

    func setup(with output: WalletNameInteractorOutput) {
        self.output = output
    }
}
