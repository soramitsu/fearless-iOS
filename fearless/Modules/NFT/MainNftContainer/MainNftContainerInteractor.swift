import UIKit
import Web3
import Web3ContractABI
import RobinHood
import SSFModels
import SSFNetwork
import SoraKeystore

final class MainNftContainerInteractor {
    // MARK: - Private properties

    private weak var output: MainNftContainerInteractorOutput?

    private let nftFetchingService: NFTFetchingServiceProtocol
    private let logger: LoggerProtocol
    private var wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol
    private var isReady: Bool = false
    private let stateHolder: MainNftContainerStateHolder
    private let userDefaultsStorage: SettingsManagerProtocol

    var showNftsLikeCollection: Bool {
        get {
            let showNftsLikeCollection: Bool = userDefaultsStorage.bool(
                for: NftAppearanceKeys.showNftsLikeCollection.rawValue
            ) ?? true
            return showNftsLikeCollection
        }
        set {
            userDefaultsStorage.set(
                value: newValue,
                for: NftAppearanceKeys.showNftsLikeCollection.rawValue
            )
        }
    }

    init(
        nftFetchingService: NFTFetchingServiceProtocol,
        logger: LoggerProtocol,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol,
        stateHolder: MainNftContainerStateHolder,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.nftFetchingService = nftFetchingService
        self.logger = logger
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.stateHolder = stateHolder
        self.userDefaultsStorage = userDefaultsStorage
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
                let filterValues: [NftCollectionFilter] = stateHolder.filters.compactMap {
                    $0.items as? [NftCollectionFilter]
                }.reduce([], +).filter { filter in
                    filter.selected
                }

                let nfts = try await nftFetchingService.fetchNfts(
                    for: wallet,
                    excludeFilters: filterValues,
                    chains: stateHolder.selectedChains
                )

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

                let ownedCollections: [NFTCollection] = nftsBySmartContract.compactMap { _, value in
                    guard let nft = value.first else {
                        return nil
                    }

                    var collection = nft.collection
                    collection?.nfts = value
                    collection?.totalSupply = nft.collection?.totalSupply

                    return collection
                }

                await MainActor.run(body: {
                    output?.didReceive(collections: ownedCollections)
                })
            } catch {
                logger.error(error.localizedDescription)
                output?.didReceive(collections: [])
            }
        }
    }

    func didSelect(chains: [ChainModel]?) {
        stateHolder.selectedChains = chains
        fetchData()
    }

    func applyFilters(_ filters: [FilterSet]) {
        stateHolder.filters = filters
        fetchData()
    }
}

extension MainNftContainerInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account
        fetchData()
    }
}
