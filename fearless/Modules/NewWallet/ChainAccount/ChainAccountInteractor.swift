import UIKit
import RobinHood
import BigInt
import SSFUtils
import SoraKeystore

final class ChainAccountInteractor {
    weak var presenter: ChainAccountInteractorOutputProtocol?
    var chainAsset: ChainAsset
    var availableChainAssets: [ChainAsset] = []

    private var wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private let eventCenter: EventCenterProtocol
    private let repository: AnyDataProviderRepository<MetaAccountModel>
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    private let chainAssetFetching: ChainAssetFetchingProtocol

    init(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        operationManager: OperationManagerProtocol,
        eventCenter: EventCenterProtocol,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol,
        chainAssetFetching: ChainAssetFetchingProtocol
    ) {
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.operationManager = operationManager
        self.eventCenter = eventCenter
        self.repository = repository
        self.availableExportOptionsProvider = availableExportOptionsProvider
        self.chainAssetFetching = chainAssetFetching
    }

    private func getAvailableChainAssets() {
        chainAssetFetching.fetch(
            filters: [.assetName(chainAsset.asset.name), .ecosystem(chainAsset.defineEcosystem())],
            sortDescriptors: []
        ) { [weak self] result in
            switch result {
            case let .success(availableChainAssets):
                self?.availableChainAssets = availableChainAssets
            default:
                self?.availableChainAssets = []
            }
        }
    }
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        getAvailableChainAssets()
    }

    func getAvailableExportOptions(for address: String) {
        fetchChainAccountFor(
            meta: wallet,
            chain: chainAsset.chain,
            address: address
        ) { [weak self] result in
            switch result {
            case let .success(chainResponse):
                guard let self = self, let response = chainResponse else {
                    self?.presenter?.didReceiveExportOptions(options: [.keystore])
                    return
                }
                let accountId = response.isChainAccount ? response.accountId : nil
                let options = self.availableExportOptionsProvider
                    .getAvailableExportOptions(
                        for: self.wallet,
                        accountId: accountId,
                        isEthereum: response.isEthereumBased
                    )
                self.presenter?.didReceiveExportOptions(options: options)
            default:
                self?.presenter?.didReceiveExportOptions(options: [.keystore])
            }
        }
    }

    func update(chain: ChainModel) {
        if let newChainAsset = availableChainAssets.first(where: { $0.chain.chainId == chain.chainId }) {
            chainAsset = newChainAsset
            presenter?.didUpdate(chainAsset: chainAsset)
        } else {
            assertionFailure("Unable to select this chain")
        }
    }
}

extension ChainAccountInteractor: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        if let updated = event.updatedChains.first(where: { [weak self] updatedChain in
            guard let self = self else { return false }
            return updatedChain.chainId == self.chainAsset.chain.chainId
        }) {
            chainAsset = ChainAsset(chain: updated, asset: chainAsset.asset)
        }
    }
}

extension ChainAccountInteractor: AccountFetching {}
