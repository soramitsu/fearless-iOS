import UIKit
import RobinHood
import BigInt

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
    private let accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let runtimeRepository: AnyDataProviderRepository<RuntimeMetadataItem>

    // MARK: - Constructor

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        wallet: MetaAccountModel,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        chainsIssuesCenter: ChainsIssuesCenter,
        chainSettingsRepository: AnyDataProviderRepository<ChainSettings>,
        accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        runtimeRepository: AnyDataProviderRepository<RuntimeMetadataItem>
    ) {
        self.wallet = wallet
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.chainsIssuesCenter = chainsIssuesCenter
        self.chainSettingsRepository = chainSettingsRepository
        self.accountInfoRepository = accountInfoRepository
        self.runtimeRepository = runtimeRepository
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
        fetchSelectedChainName()
        fetchChainSettings()

        let localMetadataOperation = runtimeRepository.fetchOperation(
            by: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
            options: RepositoryFetchOptions()
        )

        localMetadataOperation.completionBlock = {
            do {
                let runtime = try localMetadataOperation.extractNoCancellableResultData()
                print(runtime)
            } catch {
                print(error)
            }
        }

        operationQueue.addOperation(localMetadataOperation)
    }

    func testSaveOldAccountInfo() {
        let oldAccountData = OldAccountData(free: BigUInt(1_000_000_000_000), reserved: .zero, miscFrozen: BigUInt(500_000_000_000), feeFrozen: .zero)
        let oldAccountInfo = OldAccountInfo(nonce: 0, consumers: 0, providers: 0, data: oldAccountData)

        guard let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3") else {
            return
        }
        let runtimeOperation = runtimeService.fetchCoderFactoryOperation()

        runtimeOperation.completionBlock = {
            do {
                let codingFactory = try runtimeOperation.extractNoCancellableResultData()
                guard let entry = codingFactory.metadata.getStorageMetadata(
                    in: StorageCodingPath.account.moduleName,
                    storageName: StorageCodingPath.account.itemName
                ) else {
                    throw StorageDecodingOperationError.invalidStoragePath
                }

                let type = try entry.type.typeName(using: codingFactory.metadata.schemaResolver)

                let encoder = try runtimeOperation.extractNoCancellableResultData().createEncoder()
                try encoder.append(oldAccountInfo, ofType: type)
                let accountIdBytes = try encoder.encode()
                let accountInfoStorageWrapper = AccountInfoStorageWrapper(identifier: "dadc4767367320d8da7932575958add7c2982ee6c0669c58badcc39435a9a2ca", data: accountIdBytes)

                let saveOperation = self.accountInfoRepository.saveOperation {
                    [accountInfoStorageWrapper]
                } _: {
                    []
                }

                self.operationQueue.addOperation(saveOperation)
            } catch {
                print(error)
            }
        }

        operationQueue.addOperation(runtimeOperation)
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
}

// MARK: - ChainsIssuesCenterListener

extension WalletMainContainerInteractor: ChainsIssuesCenterListener {
    func handleChainsIssues(_ issues: [ChainIssue]) {
        DispatchQueue.main.async {
            self.output?.didReceiveChainsIssues(chainsIssues: issues)
        }
    }
}
