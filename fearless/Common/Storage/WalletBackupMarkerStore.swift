import CoreData
import Foundation

/// Uses one serialized context transaction, avoiding a stale fetch-then-save wallet snapshot.
protocol WalletBackupMarkerWriting {
    func recordBackup(
        of exportedWallet: MetaAccountModel,
        completion: @escaping (Result<MetaAccountModel, Error>) -> Void
    )
}

extension SelectedWalletSettings: WalletBackupMarkerWriting {}

enum WalletBackupMarkerError: Error {
    case walletMissing
    case inventoryChanged
    case contextUnavailable
}

final class WalletBackupMarkerStore: WalletBackupMarkerWriting {
    private let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func recordBackup(
        of exportedWallet: MetaAccountModel,
        completion: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        storageFacade.databaseService.performAsync { context, error in
            let result: Result<MetaAccountModel, Error> = Result {
                if let error {
                    throw error
                }
                guard let context else { throw WalletBackupMarkerError.contextUnavailable }
                let request = NSFetchRequest<CDMetaAccount>(entityName: "CDMetaAccount")
                request.predicate = NSPredicate(
                    format: "%K == %@", #keyPath(CDMetaAccount.metaId), exportedWallet.metaId
                )
                let rows = try context.fetch(request)
                guard rows.count == 1, let row = rows.first else { throw WalletBackupMarkerError.walletMissing }
                let wallet = try MetaAccountMapper().transform(entity: row)
                guard Self.sameInventory(wallet, exportedWallet) else { throw WalletBackupMarkerError.inventoryChanged }
                let previous = row.hasBackup
                row.hasBackup = true
                do {
                    try context.save()
                } catch {
                    // Restore only our field; never roll back another operation's context changes.
                    row.hasBackup = previous
                    throw error
                }
                return wallet.replacingIsBackuped(true)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func sameInventory(_ current: MetaAccountModel, _ exported: MetaAccountModel) -> Bool {
        current.metaId == exported.metaId &&
            current.substrateAccountId == exported.substrateAccountId &&
            current.substratePublicKey == exported.substratePublicKey &&
            current.substrateCryptoType == exported.substrateCryptoType &&
            current.ethereumAddress == exported.ethereumAddress &&
            current.ethereumPublicKey == exported.ethereumPublicKey &&
            current.canExportEthereumMnemonic == exported.canExportEthereumMnemonic &&
            current.chainAccounts == exported.chainAccounts &&
            current.legacyTonAccount == exported.legacyTonAccount
    }
}
