import UIKit
import RobinHood

protocol BackupWalletNameInteractorOutput: AnyObject {
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>)
}

final class BackupWalletNameInteractor {
    // MARK: - Private properties

    private weak var output: BackupWalletNameInteractorOutput?

    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>

    init(
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
    }
}

// MARK: - BackupWalletNameInteractorInput

extension BackupWalletNameInteractor: BackupWalletNameInteractorInput {
    func save(wallet: MetaAccountModel) {
        let saveOperation = repository.saveOperation {
            [wallet]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: wallet) { result in
                switch result {
                case let .success(account):
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))

                case .failure:
                    break
                }
                DispatchQueue.main.async {
                    self?.output?.didReceiveSaveOperation(result: result)
                }
            }
        }

        operationManager.enqueue(operations: [saveOperation], in: .transient)
    }

    func setup(with output: BackupWalletNameInteractorOutput) {
        self.output = output
    }
}
