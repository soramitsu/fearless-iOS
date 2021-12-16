import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

final class YourValidatorListInteractor {
    weak var presenter: YourValidatorListInteractorOutputProtocol!

    let chain: ChainModel
    let asset: AssetModel
    let selectedAccount: MetaAccountModel
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    var stashControllerProvider: StreamableProvider<StashItem>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var rewardDestinationProvider: AnyDataProvider<DecodedPayee>?
    var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    init(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    ) {
        self.chain = chain
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.eraValidatorService = eraValidatorService
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
    }

    func handle(stashItem: StashItem?, at _: EraIndex) {
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)

        let addressFactory = SS58AddressFactory()

        if let address = stashItem?.controller,
           let accountId = try? addressFactory.accountId(fromAddress: address, addressPrefix: chain.addressPrefix) {
            nominatorProvider = subscribeNomination(for: accountId, chainId: chain.chainId)
            ledgerProvider = subscribeLedgerInfo(for: accountId, chainId: chain.chainId)
            rewardDestinationProvider = subscribePayee(for: accountId, chainId: chain.chainId)
        } else {
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handle(nomination: Nomination?, stashAddress: AccountAddress, at activeEra: EraIndex) {
        guard let nomination = nomination else {
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

    func handleActiveEra(result _: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)
        clear(streamableProvider: &stashControllerProvider)

        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveValidators(result: .success(nil))
        }
    }
}

extension YourValidatorListInteractor: YourValidatorListInteractorInputProtocol {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chain.chainId)
    }

    func refresh() {
        clearAllSubscriptions()
        activeEraProvider = subscribeActiveEra(for: chain.chainId)
    }
}
