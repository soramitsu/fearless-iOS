import UIKit
import RobinHood
import IrohaCrypto
import FearlessUtils

final class AnalyticsValidatorsInteractor {
    weak var presenter: AnalyticsValidatorsInteractorOutputProtocol!
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let chain: Chain

    private var identitiesByAddress: [AccountAddress: AccountIdentity]?

    init(
        identityOperationFactory: IdentityOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        chain: Chain
    ) {
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

    private func fetchHistoryRange() {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let historyRangeWrapper = createChainHistoryRangeOperationWrapper(codingFactoryOperation: codingFactoryOperation)
        historyRangeWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

        let address = "FFnTujhiUdTbhvwcBwQ2V3UtFMdpzg4r8SYT6J7qxhwW1s3"
        let source = SQEraStakersInfoSource(
            url: URL(string: "http://localhost:3000/")!,
            address: address
        )
        let operation = source.fetch {
            try? historyRangeWrapper.targetOperation.extractNoCancellableResultData()
        }
        operation.dependencies.forEach { $0.addDependency(historyRangeWrapper.targetOperation) }

        operation.targetOperation.completionBlock = { [weak self] in
            do {
                let erasInfo = try operation.targetOperation.extractNoCancellableResultData()

                let addressFactory = SS58AddressFactory()
                let accountIds = erasInfo
                    .compactMap { validatorInfo -> AccountAddress? in
                        let contains = validatorInfo.others.contains(where: { $0.who == address })
                        return contains ? validatorInfo.address : nil
                    }
                    .compactMap { accountAddress -> AccountId? in
                        try? addressFactory.accountId(from: accountAddress)
                    }
                self?.fetchValidatorIdentity(accountIds: accountIds)
            } catch {
                print(error)
            }
        }
        operationManager.enqueue(
            operations: operation.allOperations + historyRangeWrapper.allOperations,
            in: .transient
        )
    }
}

extension AnalyticsValidatorsInteractor: AnalyticsValidatorsInteractorInputProtocol {
    func setup() {
        fetchHistoryRange()
    }
}
