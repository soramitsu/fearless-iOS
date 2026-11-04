import UIKit
import RobinHood
import CoreData

protocol WalletNameInteractorOutput: AnyObject {
    func didReceiveSaveOperation(result: Result<MetaAccountModel, Error>)
}

final class WalletNameInteractor {
    // MARK: - Private properties

    private weak var output: WalletNameInteractorOutput?

    private let eventCenter: EventCenterProtocol
    private let selectedWalletSettings: SelectedWalletSettings

    init(
        eventCenter: EventCenterProtocol,
        selectedWalletSettings: SelectedWalletSettings = .shared
    ) {
        self.eventCenter = eventCenter
        self.selectedWalletSettings = selectedWalletSettings
    }
}

// MARK: - BackupWalletNameInteractorInput

extension WalletNameInteractor: WalletNameInteractorInput {
    func save(wallet: MetaAccountModel) {
        // A rename screen can retain a wallet from before its accounts were switched.
        // Apply only the requested name to the current row and preserve its selection.
        selectedWalletSettings.performAfterPendingSaves { [weak self] in
            guard let self else { return }
            self.selectedWalletSettings.storageFacade.databaseService.performAsync { context, error in
                guard let context else {
                    self.finishSave(.failure(error ?? CoreDataRepositoryError.undefined))
                    return
                }
                do {
                    let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                    request.predicate = NSPredicate(format: "%K == %@", #keyPath(CDMetaAccount.metaId), wallet.metaId)
                    let entities = try context.fetch(request)
                    guard entities.count <= 1 else {
                        throw SelectedWalletSettingsError.duplicateWalletIdentifier
                    }
                    guard let entity = entities.first else {
                        throw PersistentValueSettingsError.missingValue
                    }
                    let name = wallet.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else {
                        throw MetaAccountMapperError.invalidWalletRecord
                    }
                    let mapper = MetaAccountMapper()
                    _ = try mapper.transform(entity: entity)
                    entity.name = name
                    let renamedWallet = try mapper.transform(entity: entity)
                    try context.save()

                    // Refresh the currently selected wallet; renaming another wallet never
                    // publishes that wallet as selected or changes its account payload.
                    self.selectedWalletSettings.setup(runningCompletionIn: .main) { result in
                        switch result {
                        case let .success(selectedWallet?):
                            let currentWallet = selectedWallet.metaId == renamedWallet.metaId
                                ? selectedWallet : renamedWallet
                            self.finishSave(.success(currentWallet))
                        case .success(nil):
                            self.finishSave(.failure(PersistentValueSettingsError.missingValue))
                        case let .failure(error):
                            self.finishSave(.failure(error))
                        }
                    }
                } catch {
                    context.rollback()
                    self.finishSave(.failure(error))
                }
            }
        }
    }

    private func finishSave(_ result: Result<MetaAccountModel, Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if case let .success(account) = result {
                self.eventCenter.notify(with: WalletNameChanged(wallet: account))
            }
            self.output?.didReceiveSaveOperation(result: result)
        }
    }

    func setup(with output: WalletNameInteractorOutput) {
        self.output = output
    }
}
