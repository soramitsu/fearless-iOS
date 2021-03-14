import Foundation
import RobinHood
import CoreData
import IrohaCrypto
import FearlessUtils

final class StakingLedgerLocalOperation: BaseOperation<StakingLedger?> {
    let storageService: CoreDataServiceProtocol
    let stashAddress: String

    init(stashAddress: String, storageService: CoreDataServiceProtocol) {
        self.storageService = storageService
        self.stashAddress = stashAddress

        super.init()
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            let payload = try fetchPayload()

            if isCancelled {
                return
            }

            if result != nil {
                return
            }

            if let payload = payload {
                do {
                    let decoder = try ScaleDecoder(data: payload)
                    let decodedItem = try StakingLedger(scaleDecoder: decoder)
                    result = .success(decodedItem)
                } catch {
                    result = .failure(error)
                }
            } else {
                result = .success(nil)
            }
        } catch {
            if isCancelled {
                return
            }

            if result != nil {
                return
            }

            result = .failure(error)
        }
    }

    private func fetchPayload() throws -> Data? {
        var payload: Data?
        var serviceError: Error?

        let currentStashAddress = stashAddress
        let semaphore = DispatchSemaphore(value: 0)

        storageService.performAsync { (context, error) in
            do {
                if let context = context {
                    let stashEntityName = String(describing: CDStashItem.self)
                    let stashRequest = NSFetchRequest<CDStashItem>(entityName: stashEntityName)
                    stashRequest.predicate = NSPredicate.filterByStash(currentStashAddress)
                    stashRequest.fetchLimit = 1

                    if let controller = try context.fetch(stashRequest).first?.controller {
                        let addressFactory = SS58AddressFactory()
                        let addressType = try addressFactory.extractAddressType(from: controller)
                        let accountId = try addressFactory.accountId(from: controller)
                        let remoteKey = try StorageKeyFactory().stakingInfoForControllerId(accountId)

                        let localKey = try ChainStorageIdFactory(chain: addressType.chain)
                            .createIdentifier(for: remoteKey)

                        let storageEntityName = String(describing: CDChainStorageItem.self)
                        let storageRequest =
                            NSFetchRequest<CDChainStorageItem>(entityName: storageEntityName)
                        storageRequest.predicate = NSPredicate.filterStorageItemsBy(identifier: localKey)
                        storageRequest.fetchLimit = 1

                        payload = try context.fetch(storageRequest).first?.data
                    }
                } else {
                    serviceError = error
                }
            } catch {
                serviceError = error
            }

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)

        if let error = serviceError {
            throw error
        }

        return payload
    }
}
