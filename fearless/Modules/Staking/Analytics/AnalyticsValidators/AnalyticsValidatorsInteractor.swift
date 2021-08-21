import UIKit
import RobinHood
import IrohaCrypto
import FearlessUtils

final class AnalyticsValidatorsInteractor {
    weak var presenter: AnalyticsValidatorsInteractorOutputProtocol!
    let selectedAddress: AccountAddress
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let chain: Chain

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var identitiesByAddress: [AccountAddress: AccountIdentity]?

    init(
        selectedAddress: AccountAddress,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        chain: Chain
    ) {
        self.selectedAddress = selectedAddress
        self.substrateProviderFactory = substrateProviderFactory
        self.singleValueProviderFactory = singleValueProviderFactory
        self.identityOperationFactory = identityOperationFactory
        self.operationManager = operationManager
        self.engine = engine
        self.runtimeService = runtimeService
        self.storageRequestFactory = storageRequestFactory
        self.chain = chain
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

    private func createChainHistoryRangeOperationWrapper(
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ChainHistoryRange> {
        let keyFactory = StorageKeyFactory()

        let currentEraWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.currentEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .currentEra
            )

        let activeEraWrapper: CompoundOperationWrapper<[StorageResponse<ActiveEraInfo>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.activeEra()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .activeEra
            )

        let historyDepthWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt32>>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keys: { [try keyFactory.historyDepth()] },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .historyDepth
            )

        let dependecies = currentEraWrapper.allOperations + activeEraWrapper.allOperations
            + historyDepthWrapper.allOperations
        dependecies.forEach { $0.addDependency(codingFactoryOperation) }

        let mergeOperation = ClosureOperation<ChainHistoryRange> {
            guard
                let currentEra = try currentEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value,
                let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.index,
                let historyDepth = try historyDepthWrapper.targetOperation.extractNoCancellableResultData()
                .first?.value?.value
            else {
                throw PayoutRewardsServiceError.unknown
            }

            return ChainHistoryRange(
                currentEra: currentEra,
                activeEra: activeEra,
                historyDepth: historyDepth
            )
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependecies)
    }

    private func fetchHistoryRange(stashAddress: AccountAddress) {
        guard let analyticsURL = chain.analyticsURL else { return }
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let historyRangeWrapper = createChainHistoryRangeOperationWrapper(codingFactoryOperation: codingFactoryOperation)
        historyRangeWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let source = SubqueryEraStakersInfoSource(url: analyticsURL, address: stashAddress)
        let operation = source.fetch {
            try? historyRangeWrapper.targetOperation.extractNoCancellableResultData()
        }
        operation.dependencies.forEach { $0.addDependency(historyRangeWrapper.targetOperation) }

        operation.targetOperation.completionBlock = { [weak self] in
            do {
                let erasInfo = try operation.targetOperation.extractNoCancellableResultData()

                DispatchQueue.main.async {
                    self?.presenter.didReceive(eraValidatorInfosResult: .success(erasInfo))
                }

                let addressFactory = SS58AddressFactory()
                let accountIds = erasInfo
                    .compactMap { validatorInfo -> AccountAddress? in
                        let contains = validatorInfo.others.contains(where: { $0.who == stashAddress })
                        return contains ? validatorInfo.address : nil
                    }
                    .compactMap { accountAddress -> AccountId? in
                        try? addressFactory.accountId(from: accountAddress)
                    }
                self?.fetchValidatorIdentity(accountIds: accountIds)
            } catch {
                DispatchQueue.main.async {
                    self?.presenter.didReceive(eraValidatorInfosResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(
            operations: operation.allOperations + historyRangeWrapper.allOperations,
            in: .transient
        )
    }

    private func handleStashAddress(_ stashAddress: AccountAddress) {
        fetchHistoryRange(stashAddress: stashAddress)
        nominationProvider = subscribeToNominationProvider(
            for: stashAddress,
            runtimeService: runtimeService
        )
    }
}

extension AnalyticsValidatorsInteractor: AnalyticsValidatorsInteractorInputProtocol {
    func setup() {
        stashItemProvider = subscribeToStashItemProvider(for: selectedAddress)
    }

    func fetchRewards(stashAddress: AccountAddress) {
        guard let analyticsURL = chain.analyticsURL else { return }
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

extension AnalyticsValidatorsInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        switch result {
        case let .success(stashItem):
            presenter.didReceive(stashItemResult: .success(stashItem))
            if let stashAddress = stashItem?.stash {
                handleStashAddress(stashAddress)
            }
        case let .failure(error):
            presenter.didReceive(stashItemResult: .failure(error))
        }
    }
}

extension AnalyticsValidatorsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handleNomination(result: Result<Nomination?, Error>, address _: AccountAddress) {
        presenter.didReceive(nominationResult: result)
        if let nomination = try? result.get() {
            fetchValidatorIdentity(accountIds: nomination.targets)
        }
    }
}
