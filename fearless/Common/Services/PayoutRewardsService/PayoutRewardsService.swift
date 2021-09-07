import Foundation
import FearlessUtils
import RobinHood
import BigInt
import IrohaCrypto

final class PayoutRewardsService: PayoutRewardsServiceProtocol {
    let selectedAccountAddress: String
    let chain: Chain
    let validatorsResolutionFactory: PayoutValidatorsFactoryProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let payoutInfoFactory: PayoutInfoFactoryProtocol
    let logger: LoggerProtocol?

    init(
        selectedAccountAddress: String,
        chain: Chain,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.validatorsResolutionFactory = validatorsResolutionFactory
        self.runtimeCodingService = runtimeCodingService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.operationManager = operationManager
        self.identityOperationFactory = identityOperationFactory
        self.payoutInfoFactory = payoutInfoFactory
        self.logger = logger
    }

    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo> {
        do {
            let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

            let historyRangeWrapper = try createChainHistoryRangeOperationWrapper(
                codingFactoryOperation: codingFactoryOperation
            )

            historyRangeWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let validatorsWrapper = validatorsResolutionFactory
                .createResolutionOperation(for: selectedAccountAddress) {
                    try historyRangeWrapper.targetOperation.extractNoCancellableResultData().eraRange
                }

            validatorsWrapper.addDependency(wrapper: historyRangeWrapper)

            let controllersWrapper: CompoundOperationWrapper<[Data]> = try createFetchAndMapOperation(
                dependingOn: validatorsWrapper.targetOperation,
                codingFactoryOperation: codingFactoryOperation,
                path: .controller
            )
            controllersWrapper.allOperations
                .forEach {
                    $0.addDependency(validatorsWrapper.targetOperation)
                    $0.addDependency(codingFactoryOperation)
                }

            let ledgerInfos: CompoundOperationWrapper<[StakingLedger]> =
                try createFetchAndMapOperation(
                    dependingOn: controllersWrapper.targetOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .stakingLedger
                )

            ledgerInfos.allOperations
                .forEach { $0.addDependency(controllersWrapper.targetOperation) }

            let unclaimedErasByStashOperation = try createUnclaimedEraByStashOperation(
                ledgerInfoOperation: ledgerInfos.targetOperation,
                historyRangeOperation: historyRangeWrapper.targetOperation
            )

            unclaimedErasByStashOperation.addDependency(ledgerInfos.targetOperation)
            unclaimedErasByStashOperation.addDependency(historyRangeWrapper.targetOperation)

            let erasRewardDistributionWrapper = try createErasRewardDistributionOperationWrapper(
                dependingOn: unclaimedErasByStashOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            erasRewardDistributionWrapper.allOperations.forEach {
                $0.addDependency(unclaimedErasByStashOperation)
            }

            let exposuresByEraWrapper: CompoundOperationWrapper<[EraIndex: [Data: ValidatorExposure]]> =
                try createCreateHistoryByEraAccountIdOperation(
                    dependingOn: unclaimedErasByStashOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .validatorExposureClipped
                )

            exposuresByEraWrapper.allOperations
                .forEach { $0.addDependency(unclaimedErasByStashOperation) }

            let prefsByEraWrapper: CompoundOperationWrapper<[EraIndex: [Data: ValidatorPrefs]]> =
                try createCreateHistoryByEraAccountIdOperation(
                    dependingOn: unclaimedErasByStashOperation,
                    codingFactoryOperation: codingFactoryOperation,
                    path: .erasPrefs
                )

            prefsByEraWrapper.allOperations
                .forEach { $0.addDependency(unclaimedErasByStashOperation) }

            let eraInfoOperation = createEraValidatorsInfoOperation(
                dependingOn: exposuresByEraWrapper.targetOperation,
                dependingOn: prefsByEraWrapper.targetOperation
            )

            exposuresByEraWrapper.allOperations.forEach { eraInfoOperation.addDependency($0) }
            prefsByEraWrapper.allOperations.forEach { eraInfoOperation.addDependency($0) }

            let identityWrapper = createIdentityFetchOperation(
                dependingOn: eraInfoOperation
            )

            identityWrapper.allOperations.forEach { $0.addDependency(eraInfoOperation) }

            let payoutOperation = try calculatePayouts(
                for: payoutInfoFactory,
                dependingOn: eraInfoOperation,
                erasRewardOperation: erasRewardDistributionWrapper.targetOperation,
                historyRangeOperation: historyRangeWrapper.targetOperation,
                identityOperation: identityWrapper.targetOperation
            )

            payoutOperation.addDependency(eraInfoOperation)
            payoutOperation.addDependency(identityWrapper.targetOperation)
            payoutOperation.addDependency(erasRewardDistributionWrapper.targetOperation)
            payoutOperation.addDependency(historyRangeWrapper.targetOperation)

            let overviewOperations: [Operation] = {
                var array = [Operation]()
                array.append(contentsOf: historyRangeWrapper.allOperations)
                array.append(contentsOf: erasRewardDistributionWrapper.allOperations)
                array.append(codingFactoryOperation)
                return array
            }()
            let validatorsResolutionOperations: [Operation] = {
                var array = [Operation]()
                array.append(contentsOf: validatorsWrapper.allOperations)
                array.append(contentsOf: controllersWrapper.allOperations)
                array.append(contentsOf: ledgerInfos.allOperations)
                array.append(unclaimedErasByStashOperation)
                return array
            }()
            let validatorsAndEraInfoOperations: [Operation] = {
                var array = [Operation]()
                array.append(contentsOf: exposuresByEraWrapper.allOperations)
                array.append(contentsOf: prefsByEraWrapper.allOperations)
                array.append(contentsOf: identityWrapper.allOperations)
                array.append(eraInfoOperation)
                return array
            }()

            let dependencies = overviewOperations + validatorsResolutionOperations
                + validatorsAndEraInfoOperations

            return CompoundOperationWrapper(
                targetOperation: payoutOperation,
                dependencies: dependencies
            )

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
