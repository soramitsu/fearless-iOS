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
    func setup(with output: MainNftContainerInteractorOutput) {
        self.output = output
    }

    func fetchData() {
        Task {
            do {
                let nfts = try await nftFetchingService.fetchNfts(for: wallet)

                let nftsBySmartContract: [String: [NFT]] = nfts.reduce([String: [NFT]]()) { partialResult, nft in
                    var map = partialResult

                    guard let smartContract = nft.smartContract else {
                        return map
                    }

                    if var nfts = partialResult[smartContract] {
                        nfts.append(nft)
                        map[smartContract] = nfts
                    } else {
                        map[smartContract] = [nft]
                    }

                    return map
                }

                let collections: [NFTCollection] = nftsBySmartContract.compactMap { _, value in
                    guard let nft = value.first else {
                        return nil
                    }

                    var collection = nft.collection
                    collection?.nfts = value

                    return collection
                }

                await MainActor.run(body: {
                    output?.didReceive(collections: collections)
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
