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

                let ownedCollections = try await nftFetchingService.fetchCollections(
                    for: wallet,
                    excludeFilters: filterValues,
                    chains: stateHolder.selectedChains
                )

                let collections = ownedCollections.map { collection in
                    var ownedCollection = collection
                    ownedCollection.nfts = nfts.filter { $0.smartContract == collection.address }
                    return ownedCollection
                }.filter { $0.nfts?.isEmpty == false }

                await MainActor.run(body: {
                    output?.didReceive(collections: collections)
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
