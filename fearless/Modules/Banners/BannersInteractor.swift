import UIKit
import SCard
import SoraKeystore
import RobinHood
import SSFModels

protocol BannersInteractorOutput: AnyObject {
    func didReceive(error: Error)
    func didReceive(wallet: MetaAccountModel)
}

final class BannersInteractor {
    // MARK: - Private properties

    private weak var output: BannersInteractorOutput?

    private let walletProvider: StreamableProvider<ManagedMetaAccountModel>
    private let chainAssetFetching: ChainAssetFetchingProtocol
    private let eventCenter: EventCenterProtocol
    private let userDefaults: SettingsManagerProtocol

    init(
        walletProvider: StreamableProvider<ManagedMetaAccountModel>,
        chainAssetFetching: ChainAssetFetchingProtocol,
        eventCenter: EventCenterProtocol,
        userDefaults: SettingsManagerProtocol
    ) {
        self.walletProvider = walletProvider
        self.chainAssetFetching = chainAssetFetching
        self.eventCenter = eventCenter
        self.userDefaults = userDefaults
    }

    // MARK: - Private methods
}

// MARK: - BannersInteractorInput

extension BannersInteractor: BannersInteractorInput {
    var shouldShowAddWalletBanner: Bool {
        get {
            userDefaults.shouldShowAddWalletBanner
        }
        set {
            userDefaults.shouldShowAddWalletBanner = newValue
        }
    }

    func setup(with output: BannersInteractorOutput) {
        self.output = output
    }

    func markWalletAsBackedUp(_ wallet: MetaAccountModel) {
        let updatedWallet = wallet.replacingIsBackuped(true)

        SelectedWalletSettings.shared.performSave(value: updatedWallet) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(account):
                    self?.output?.didReceive(wallet: account)
                    let event = MetaAccountModelChangedEvent(account: account)
                    self?.eventCenter.notify(with: event)
                case let .failure(error):
                    self?.output?.didReceive(error: error)
                }
            }
        }
    }

    func subscribeToWallet() {
        let updateClosure: ([DataProviderChange<ManagedMetaAccountModel>]) -> Void = { [weak self] changes in
            guard let wallet = changes.reduceToLastChange() else {
                return
            }
            self?.output?.didReceive(wallet: wallet.info)
            changes.forEach { change in
                switch change {
                case .insert(newItem: let newItem):
                    self?.output?.didReceive(wallet: newItem.info)
                case .update(newItem: let newItem):
                    self?.output?.didReceive(wallet: newItem.info)
                case .delete(deletedIdentifier: let deletedIdentifier):
                    break
                }
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.output?.didReceive(error: error)
        }

        let options = StreamableProviderObserverOptions()

        walletProvider.addObserver(
            self,
            deliverOn: .global(),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func initSoraCard() async throws -> SCard {
        if let soraCardService = SCard.shared {
            return soraCardService
        }
        
        guard let wallet = SelectedWalletSettings.shared.value else { throw ConvenienceError(error: "wallet not found") }

        guard let soraChainAsset = try await chainAssetFetching.fetchAwait(
            shouldUseCache: true,
            filters: [.chainId(Chain.soraMain.genesisHash)],
            sortDescriptors: []
        ).first else {
            throw ConvenienceError(error: "XOR chainAsset not found")
        }

        return await MainActor.run {
            let service = SCardService(
                wallet: wallet,
                soraChainAsset: soraChainAsset
            )
            let soraCardService = service.initSoraCard()
            return soraCardService
        }
    }
}
