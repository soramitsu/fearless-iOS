import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

final class YourValidatorListInteractor: AccountFetching {
    weak var presenter: YourValidatorListInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let selectedAccount: MetaAccountModel
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>

    var stashControllerProvider: StreamableProvider<StashItem>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var rewardDestinationProvider: AnyDataProvider<DecodedPayee>?
    var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    var activeEraInfo: ActiveEraInfo?
    var stashAddress: String?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.eraValidatorService = eraValidatorService
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountRepository = accountRepository
    }

    func fetchController(for address: AccountAddress) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: address,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveController(result: result)
        }
    }

    func createValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        if nomination.submittedIn >= activeEra {
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
        } else {
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

extension YourValidatorListInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler, AnyProviderAutoCleaning {
    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveLedger(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        do {
            let payee = try result.get()
            presenter.didReceiveRewardDestination(result: .success(payee))
        } catch {
            presenter.didReceiveRewardDestination(result: .failure(error))
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        activeEraInfo = try? result.get()

        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)
        clear(streamableProvider: &stashControllerProvider)

        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)

        let addressFactory = SS58AddressFactory()

        if let stashItem = try? result.get(),
           let controllerAccountId = try? addressFactory.accountId(
               fromAddress: stashItem.controller,
               addressPrefix: chainAsset.chain.addressPrefix
           ),
           let stashAccountId = try? addressFactory.accountId(
               fromAddress: stashItem.stash,
               type: chainAsset.chain.addressPrefix
           ) {
            presenter.didReceiveStashItem(result: .success(stashItem))

            stashAddress = stashItem.controller

            fetchController(for: stashItem.controller)

            nominatorProvider = subscribeNomination(for: stashAccountId, chainAsset: chainAsset)
            ledgerProvider = subscribeLedgerInfo(for: controllerAccountId, chainAsset: chainAsset)
            rewardDestinationProvider = subscribePayee(for: stashAccountId, chainAsset: chainAsset)

        } else {
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        guard let nomination = try? result.get(),
              let activeEra = activeEraInfo?.index,
              let stashAddress = stashAddress else {
            presenter.didReceiveValidators(result: .success(nil))
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
                    self?.presenter.didReceiveValidators(result: .success(result))
                } catch {
                    self?.presenter.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: validatorsWrapper.allOperations, in: .transient)
    }
}

extension YourValidatorListInteractor: YourValidatorListInteractorInputProtocol {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }

    func refresh() {
        clearAllSubscriptions()
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }
}
