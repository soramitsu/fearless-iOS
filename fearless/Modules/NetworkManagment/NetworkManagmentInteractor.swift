import UIKit
import RobinHood
import SSFModels

protocol NetworkManagmentInteractorOutput: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveUpdated(wallet: MetaAccountModel)
}

final class NetworkManagmentInteractor {
    // MARK: - Private properties

    private weak var output: NetworkManagmentInteractorOutput?

    private var wallet: MetaAccountModel
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let chainModels: [ChainModel]?
    private let eventCenter: EventCenterProtocol

    init(
        wallet: MetaAccountModel,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        chainModels: [ChainModel]?,
        eventCenter: EventCenterProtocol
    ) {
        self.wallet = wallet
        self.accountRepository = accountRepository
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.chainModels = chainModels
        self.eventCenter = eventCenter
    }

    private func fetchChains() {
        if let chainModels = chainModels {
            handleChains(result: .success(chainModels))
            return
        }
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            output?.didReceiveChains(result: .success(chains))
        case let .failure(error):
            output?.didReceiveChains(result: .failure(error))
        case .none:
            output?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func save(_ updatedAccount: MetaAccountModel?) {
        guard let updatedAccount = updatedAccount else {
            return
        }
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(wallet):
                    self?.wallet = wallet
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: wallet))
                    DispatchQueue.main.async {
                        self?.output?.didReceiveUpdated(wallet: wallet)
                    }
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

// MARK: - NetworkManagmentInteractorInput

extension NetworkManagmentInteractor: NetworkManagmentInteractorInput {
    func didTapFavoutite(with identifire: String) {
        var updatedWallet: MetaAccountModel?
        if wallet.favouriteChainIds.contains(identifire) {
            let updatedFavourites = wallet.favouriteChainIds.filter { $0 != identifire }
            updatedWallet = wallet.replacingFavoutites(updatedFavourites)
        } else {
            let updatedFavourites = wallet.favouriteChainIds + [identifire]
            updatedWallet = wallet.replacingFavoutites(updatedFavourites)
        }
        save(updatedWallet)
    }

    func setup(with output: NetworkManagmentInteractorOutput) {
        self.output = output
        fetchChains()
    }
}
