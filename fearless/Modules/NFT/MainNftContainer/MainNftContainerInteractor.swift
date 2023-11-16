import UIKit
import Web3
import Web3ContractABI
import RobinHood
import SSFModels
import SSFNetwork

final class MainNftContainerInteractor {
    // MARK: - Private properties

    private weak var output: MainNftContainerInteractorOutput?

    private let nftFetchingService: NFTFetchingServiceProtocol
    private let logger: LoggerProtocol
    private var wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol
    private var isReady: Bool = false

    init(
        nftFetchingService: NFTFetchingServiceProtocol,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.nftFetchingService = nftFetchingService
        self.logger = logger
        self.wallet = wallet
        self.eventCenter = eventCenter
        eventCenter.add(observer: self)
    }
}

// MARK: - MainNftContainerInteractorInput

extension MainNftContainerInteractor: MainNftContainerInteractorInput {
    func initialSetup() {
        let wasReady = isReady
        isReady = true

        if !wasReady {
            fetchData()
        }
    }

    func setup(with output: MainNftContainerInteractorOutput) {
        self.output = output
    }

    func fetchData() {
        guard isReady else {
            return
        }

        Task {
            do {
                let nfts = try await nftFetchingService.fetchNfts(for: wallet)

                var ownedCollections = try await nftFetchingService.fetchCollections(for: wallet)

                ownedCollections = ownedCollections.map { collection in
                    var ownedCollection = collection
                    ownedCollection.nfts = nfts.filter { $0.smartContract == collection.address }
                    return ownedCollection
                }.filter { $0.nfts?.isEmpty == false }

                let filledCollections = try await withThrowingTaskGroup(of: [NFT]?.self) { [weak self] group in
                    guard let strongSelf = self else {
                        return ownedCollections
                    }

                    var updatedCollections: [NFTCollection] = []

                    for collection in ownedCollections {
                        if let address = collection.address {
                            group.addTask {
                                let nfts = try? await strongSelf.nftFetchingService.fetchCollectionNfts(
                                    collectionAddress: address,
                                    chain: collection.chain
                                )
                                return nfts
                            }
                        } else {
                            updatedCollections.append(collection)
                        }
                    }
                    for try await collectionNfts in group {
                        if var collection = ownedCollections.first(where: { collection in
                            collection.address == collectionNfts?.first?.smartContract
                        }) {
                            collection.availableNfts = collectionNfts
                            updatedCollections.append(collection)
                        }
                    }
                    return updatedCollections
                }

                await MainActor.run(body: {
                    output?.didReceive(collections: filledCollections)
                })
            } catch {
                logger.error(error.localizedDescription)
            }
        }
    }
}

extension MainNftContainerInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account
    }

    func processChainsSetupCompleted() {
        fetchData()
    }
}
