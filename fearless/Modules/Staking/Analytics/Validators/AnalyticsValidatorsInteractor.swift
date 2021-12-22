import UIKit
import RobinHood
import IrohaCrypto
import FearlessUtils

final class AnalyticsValidatorsInteractor {
    weak var presenter: AnalyticsValidatorsInteractorOutputProtocol!
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let logger: LoggerProtocol?

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var currentEraProvider: AnyDataProvider<DecodedEraIndex>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var identitiesByAddress: [AccountAddress: AccountIdentity]?
    private var currentEra: EraIndex?
    private var nomination: Nomination?
    private var stashItem: StashItem?

    init(
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.substrateProviderFactory = substrateProviderFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.identityOperationFactory = identityOperationFactory
        self.operationManager = operationManager
        self.engine = engine
        self.runtimeService = runtimeService
        self.storageRequestFactory = storageRequestFactory
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.logger = logger
    }

    private func fetchValidatorIdentity(accountIds: [AccountId]) {
        let operation = identityOperationFactory.createIdentityWrapper(
            for: { accountIds },
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )
        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let identitiesByAddress = try operation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(identitiesByAddressResult: .success(identitiesByAddress))
                } catch {
                    self?.presenter.didReceive(identitiesByAddressResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }

    private func fetchEraStakers() {
        guard
            let analyticsURL = chain.externalApi?.staking?.url,
            let stashAddress = stashItem?.stash,
            let nomination = nomination,
            let currentEra = currentEra
        else { return }

        let eraRange = EraRange(start: nomination.submittedIn + 1, end: currentEra)

        DispatchQueue.main.async { [weak self] in
            self?.presenter.didReceive(eraRange: eraRange)
        }

        let source = SubqueryEraStakersInfoSource(url: analyticsURL, address: stashAddress)
        let fetchOperation = source.fetch { eraRange }

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let erasInfo = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraValidatorInfosResult: .success(erasInfo))
                } catch {
                    self?.presenter.didReceive(eraValidatorInfosResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }

    private func fetchRewards() {
        guard
            let analyticsURL = chain.externalApi?.staking?.url,
            let stashAddress = stashItem?.stash
        else { return }

        let subqueryRewardsSource = SubqueryRewardsSource(address: stashAddress, url: analyticsURL)
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceive(rewardsResult: .success(response))
                } catch {
                    self?.presenter.didReceive(rewardsResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsValidatorsInteractor: AnalyticsValidatorsInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        currentEraProvider = subscribeCurrentEra(for: chain.chainId)
    }

    func reload() {
        fetchEraStakers()
        fetchRewards()
    }
}

extension AnalyticsValidatorsInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            self.stashItem = stashItem

            if let stashAddress = stashItem?.stash {
                presenter.didReceive(stashAddressResult: .success(stashAddress))

                let addressFactory = SS58AddressFactory()
                if let accountId = try? addressFactory.accountId(fromAddress: stashAddress, type: chain.addressPrefix) {
                    nominationProvider = subscribeNomination(for: accountId, chainId: chain.chainId)
                }

                fetchRewards()
            }
        case let .failure(error):
            presenter.didReceive(stashAddressResult: .failure(error))
        }
    }

    func handleCurrentEra(result: Result<EraIndex?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(currentEra):
            self.currentEra = currentEra
            fetchEraStakers()
        case let .failure(error):
            logger?.error("Gor error on currentEra subscription: \(error.localizedDescription)")
        }
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceive(nominationResult: result)
        switch result {
        case let .success(nomination):
            self.nomination = nomination
            if let nomination = nomination {
                fetchValidatorIdentity(accountIds: nomination.targets)
            }
            fetchEraStakers()
        case let .failure(error):
            logger?.error("Gor error on nomination request: \(error.localizedDescription)")
        }
    }
}
