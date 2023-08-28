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

    private func fetchData() {
        Task {
            do {
                let nftsHistory = try await nftFetchingService.fetchNftsHistory(for: wallet)

                await MainActor.run(body: {
                    output?.didReceive(history: nftsHistory)
                })

                let nfts = try await nftFetchingService.fetchNfts(for: nftsHistory)

                let nftsBySmartContract: [String: [NFT]] = nfts.reduce([String: [NFT]]()) { partialResult, nft in
                    var map = partialResult

                    if var nfts = partialResult[nft.smartContract] {
                        nfts.append(nft)
                        map[nft.smartContract] = nfts
                    } else {
                        map[nft.smartContract] = [nft]
                    }

                    return map
                }

                await MainActor.run(body: {
                    output?.didReceive(nfts: nfts)
                })
            } catch {
                logger.error(error.localizedDescription)
            }
        }
    }
}

// MARK: - MainNftContainerInteractorInput

extension MainNftContainerInteractor: MainNftContainerInteractorInput {
    func setup(with output: MainNftContainerInteractorOutput) {
        self.output = output

        fetchData()
    }
}

extension MainNftContainerInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account
        fetchData()
    }
}
