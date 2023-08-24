import UIKit
import RobinHood
import SSFModels

final class WalletMainContainerInteractor {
    // MARK: - Private properties

    private weak var output: WalletMainContainerInteractorOutput?

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private var wallet: MetaAccountModel
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol
    private let chainsIssuesCenter: ChainsIssuesCenter
    private let chainSettingsRepository: AnyDataProviderRepository<ChainSettings>
    private let deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckService

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AnyDataProviderRepository<ChainSettings>,
        deprecatedAccountsCheckService: DeprecatedControllerStashAccountCheckService
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
        self.deprecatedAccountsCheckService = deprecatedAccountsCheckService
    }

    // MARK: - Private methods

    private func fetchSelectedChainName() {
        guard let chainId = wallet.chainIdForFilter else {
            DispatchQueue.main.async {
                self.output?.didReceiveSelectedChain(nil)
            }
            return
        }

        let operation = chainRepository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        operation.completionBlock = { [weak self] in
            guard let result = operation.result else {
                DispatchQueue.main.async {
                    self?.output?.didReceiveError(BaseOperationError.unexpectedDependentResult)
                }
                return
            }

            DispatchQueue.main.async {
                switch result {
                case let .success(chain):
                    self?.output?.didReceiveSelectedChain(chain)
                case let .failure(error):
                    self?.output?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func save(
        _ updatedAccount: MetaAccountModel
    ) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    self?.wallet = account
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    self?.fetchSelectedChainName()
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    private func fetchChainSettings() {
        let fetchChainSettingsOperation = chainSettingsRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchChainSettingsOperation.completionBlock = { [weak self] in
            let chainSettings = (try? fetchChainSettingsOperation.extractNoCancellableResultData()) ?? []
            DispatchQueue.main.async {
                self?.output?.didReceive(chainSettings: chainSettings)
            }
        }

        operationQueue.addOperation(fetchChainSettingsOperation)
    }

    private func checkDeprecatedAccountIssues() {
        Task {
            if let issue = try? await deprecatedAccountsCheckService.checkAccountDeprecations() {
                switch issue {
                case let .controller(chainAsset):
                    DispatchQueue.main.async {
                        self.output?.didReceiveControllerAccountIssue(chainAsset: chainAsset)
                    }
                case let .stash(address):
                    DispatchQueue.main.async {
                        self.output?.didReceiveStashAccountIssue(address: address)
                    }
                }
            }
        }
    }
}

// MARK: - WalletMainContainerInteractorInput

extension WalletMainContainerInteractor: WalletMainContainerInteractorInput {
    func saveChainIdForFilter(_ chainId: ChainModel.Id?) {
        var updatedAccount: MetaAccountModel?

        if chainId != wallet.chainIdForFilter {
            updatedAccount = wallet.replacingChainIdForFilter(chainId)
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount)
        }
    }

    func setup(with output: WalletMainContainerInteractorOutput) {
        self.output = output
        eventCenter.add(observer: self, dispatchIn: .main)
        chainsIssuesCenter.addIssuesListener(self, getExisting: true)
        checkDeprecatedAccountIssues()
        fetchSelectedChainName()
        fetchChainSettings()
    }
}

// MARK: - EventVisitorProtocol

extension WalletMainContainerInteractor: EventVisitorProtocol {
    func processWalletNameChanged(event: WalletNameChanged) {
        if wallet.identifier == event.wallet.identifier {
            wallet = event.wallet
            output?.didReceiveAccount(wallet)
        }
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        wallet = event.account
        output?.didReceiveAccount(event.account)
    }

    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }

        self.wallet = wallet
        output?.didReceiveAccount(wallet)

        fetchSelectedChainName()
    }
}

// MARK: - ChainsIssuesCenterListener

extension WalletMainContainerInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        DispatchQueue.main.async {
            self.output?.didReceiveChainsIssues(chainsIssues: issues)
        }
    }
}
