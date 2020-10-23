import Foundation
import RobinHood
import IrohaCrypto

protocol WalletContactOperationFactoryProtocol {
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void>
    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]>
}

final class WalletContactOperationFactory {
    let repository: AnyDataProviderRepository<ContactItem>
    let targetAddress: String

    init(storageFacade: StorageFacadeProtocol, targetAddress: String) {
        let filter = NSPredicate.filterContactsByTarget(address: targetAddress)
        let repository: CoreDataRepository<ContactItem, CDContactItem> =
            storageFacade.createRepository(filter: filter,
                                           sortDescriptors: [NSSortDescriptor.contactsByTime])

        self.repository = AnyDataProviderRepository(repository)
        self.targetAddress = targetAddress
    }
}

extension WalletContactOperationFactory: WalletContactOperationFactoryProtocol {
    func saveByAddressOperation(_ address: String) -> CompoundOperationWrapper<Void> {
        let fetchOperation = repository.fetchOperation(by: address,
                                                       options: RepositoryFetchOptions())

        let currentTargetAddress = targetAddress
        let saveOperation = repository.saveOperation({
            let existingContact = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let contactItem = ContactItem(peerAddress: address,
                                          peerName: existingContact?.peerName,
                                          targetAddress: currentTargetAddress,
                                          updatedAt: Int64(Date().timeIntervalSince1970))

            return [contactItem]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation,
                                        dependencies: [fetchOperation])
    }

    func fetchContactsOperation() -> CompoundOperationWrapper<[ContactItem]> {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
