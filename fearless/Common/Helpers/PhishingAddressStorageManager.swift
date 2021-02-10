import Foundation
import IrohaCrypto
import CoreData
import RobinHood

protocol PhishingAddressRepositoryFacadeProtocol {
    func updateRepository(from data: [String: AnyObject])

    func fetchAddress(publicKey: String,
                      completionHandler: @escaping (Result<PhishingItem?, Error>?) -> Void) throws
}

class PhishingAddressStorageManager: PhishingAddressRepositoryFacadeProtocol {
    let logger = Logger.shared
    let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
        SubstrateDataStorageFacade.shared.createRepository()

    func updateRepository(from data: [String: AnyObject]) {
        self.clearRepository()

        for (key, value) in data {
            if let addresses = value as? [String] {
                for address in addresses {
                    do {
                        let typeRawValue = try SS58AddressFactory().type(fromAddress: address)

                        guard let addressType = SNAddressType(rawValue: typeRawValue.uint8Value) else {
                            continue
                        }

                        let accountId = try SS58AddressFactory().accountId(fromAddress: address,
                                                                           type: addressType)

                        let item = PhishingItem(source: key,
                                                publicKey: accountId.toHex())

                        let operation = storage.saveOperation({ [item] }, { [] })
                        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)
                    } catch {
                        logger.error("Scam address saving error: \(error)")
                        continue
                    }
                }
            }
        }
    }

    func fetchAddress(publicKey: String,
                      completionHandler: @escaping (Result<PhishingItem?, Error>?) -> Void) throws {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let fetchOperation = storage.fetchOperation(by: publicKey,
                                                    options: RepositoryFetchOptions())
        fetchOperation.completionBlock = {
            DispatchQueue.main.async {
                completionHandler(fetchOperation.result)
            }
        }

        OperationManagerFacade.sharedManager.enqueue(operations: [fetchOperation], in: .sync)
    }

    private func clearRepository() {
        let storage: CoreDataRepository<PhishingItem, CDPhishingItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let operation = storage.deleteAllOperation()
        OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .sync)
    }
}
