import Foundation
import RobinHood

protocol YourValidatorListRelaychainStrategyOutput {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveLedger(result: Result<StakingLedger?, Error>)
    func didReceiveRewardDestination(result: Result<RewardDestinationArg?, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
}

final class YourValidatorListRelaychainStrategy: AccountFetching {
    private let output: YourValidatorListRelaychainStrategyOutput?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let eraValidatorService: EraValidatorServiceProtocol
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var nominatorProvider: AnyDataProvider<DecodedNomination>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var rewardDestinationProvider: AnyDataProvider<DecodedPayee>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    private var activeEraInfo: ActiveEraInfo?
    private var stashAddress: String?

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        output: YourValidatorListRelaychainStrategyOutput?
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.eraValidatorService = eraValidatorService
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountRepository = accountRepository
        self.output = output
    }

    func fetchController(for address: AccountAddress) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: address,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.output?.didReceiveController(result: result)
        }
    }

    private func createValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        if nomination.submittedIn >= activeEra {
            return createActiveValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress,
                activeEra: activeEra
            )
        } else {
            return createSelectedValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress,
                activeEra: activeEra
            )
        }
    }

    private func createActiveValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra _: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        let activeValidatorsWrapper = validatorOperationFactory.activeValidatorsOperation(
            for: stashAddress
        )

        let selectedValidatorsWrapper = validatorOperationFactory.pendingValidatorsOperation(
            for: nomination.targets
        )

        let mergeOperation = ClosureOperation<YourValidatorsModel> {
            let activeValidators = try activeValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()
            let selectedValidators = try selectedValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()

            return YourValidatorsModel(
                currentValidators: activeValidators,
                pendingValidators: selectedValidators
            )
        }

        mergeOperation.addDependency(selectedValidatorsWrapper.targetOperation)
        mergeOperation.addDependency(activeValidatorsWrapper.targetOperation)

        let dependencies = selectedValidatorsWrapper.allOperations + activeValidatorsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func createSelectedValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra _: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        let selectedValidatorsWrapper = validatorOperationFactory.allSelectedOperation(
            by: nomination,
            nominatorAddress: stashAddress
        )

        let mapOperation = ClosureOperation<YourValidatorsModel> {
            let curentValidators = try selectedValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()

            return YourValidatorsModel(
                currentValidators: curentValidators,
                pendingValidators: []
            )
        }

        mapOperation.addDependency(selectedValidatorsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: selectedValidatorsWrapper.allOperations
        )
    }

    func clearAllSubscriptions() {
        clear(dataProvider: &activeEraProvider)
        clear(streamableProvider: &stashControllerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)
    }

    func clearActiveEraSubscription() {
        clear(dataProvider: &activeEraProvider)
    }
}

extension YourValidatorListRelaychainStrategy: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        output?.didReceiveLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        do {
            let payee = try result.get()
            output?.didReceiveRewardDestination(result: .success(payee))
        } catch {
            output?.didReceiveRewardDestination(result: .failure(error))
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        activeEraInfo = try? result.get()

        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)
        clear(streamableProvider: &stashControllerProvider)

        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        } else {
            output?.didReceiveValidators(result: .success(nil))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)

        if let stashItem = try? result.get(),
           let controllerAccountId = try? AddressFactory.accountId(
               from: stashItem.controller,
               chain: chainAsset.chain
           ),
           let stashAccountId = try? AddressFactory.accountId(
               from: stashItem.stash,
               chain: chainAsset.chain
           ) {
            output?.didReceiveStashItem(result: .success(stashItem))

            stashAddress = stashItem.controller

            fetchController(for: stashItem.controller)

            nominatorProvider = subscribeNomination(for: stashAccountId, chainAsset: chainAsset)
            ledgerProvider = subscribeLedgerInfo(for: controllerAccountId, chainAsset: chainAsset)
            rewardDestinationProvider = subscribePayee(for: stashAccountId, chainAsset: chainAsset)

        } else {
            output?.didReceiveValidators(result: .success(nil))
        }
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        guard let nomination = try? result.get(),
              let activeEra = activeEraInfo?.index,
              let stashAddress = stashAddress else {
            output?.didReceiveValidators(result: .success(nil))
            return
        }

        let validatorsWrapper = createValidatorsWrapper(
            for: nomination,
            stashAddress: stashAddress,
            activeEra: activeEra
        )

        validatorsWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveValidators(result: .success(result))
                } catch {
                    self?.output?.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: validatorsWrapper.allOperations, in: .transient)
    }
}

extension YourValidatorListRelaychainStrategy: YourValidatorListStrategy {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }

    func refresh() {
        clearAllSubscriptions()
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }
}
