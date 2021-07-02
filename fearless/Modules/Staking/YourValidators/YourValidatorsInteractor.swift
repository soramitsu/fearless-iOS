import UIKit
import SoraKeystore
import RobinHood

final class YourValidatorsInteractor {
    weak var presenter: YourValidatorsInteractorOutputProtocol!

    let chain: Chain
    let providerFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let settings: SettingsManagerProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    let accountRepository: AnyDataProviderRepository<AccountItem>

    var stashControllerProvider: StreamableProvider<StashItem>?
    var nominatorProvider: AnyDataProvider<DecodedNomination>?
    var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    var rewardDestinationProvider: AnyDataProvider<DecodedPayee>?
    var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    init(
        chain: Chain,
        providerFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        settings: SettingsManagerProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        runtimeService: RuntimeCodingServiceProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.providerFactory = providerFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.settings = settings
        self.accountRepository = accountRepository
        self.runtimeService = runtimeService
        self.eraValidatorService = eraValidatorService
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
    }

    func fetchController(for address: AccountAddress) {
        let operation = accountRepository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let accountItem = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveController(result: .success(accountItem))
                } catch {
                    self?.presenter.didReceiveController(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func handle(activeEra: EraIndex?) {
        clearStashControllerProvider()
        clearNominatorProvider()
        clearLedgerProvider()
        clearRewardDestinationProvider()

        if let activeEra = activeEra {
            subscribeToStashControllerProvider(at: activeEra)
        } else {
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handle(stashItem: StashItem?, at activeEra: EraIndex) {
        clearNominatorProvider()
        clearLedgerProvider()
        clearRewardDestinationProvider()

        if let stashItem = stashItem {
            fetchController(for: stashItem.controller)
            subscribeToNominator(address: stashItem.stash, at: activeEra)
            subscribeToLedger(for: stashItem.controller)
            subscribeToRewardDestination(for: stashItem.stash)
        } else {
            presenter.didReceiveController(result: .success(nil))
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
}

extension YourValidatorsInteractor: YourValidatorsInteractorInputProtocol {
    func setup() {
        subscribeToActiveEraProvider()
    }

    func refresh() {
        clearAllSubscriptions()
        subscribeToActiveEraProvider()
    }
}
