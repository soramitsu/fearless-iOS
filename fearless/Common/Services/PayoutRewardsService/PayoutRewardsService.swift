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
        self.logger = logger
    }

    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo> {
        do {
            let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

            let historyRangeWrapper = try createChainHistoryRangeOperationWrapper(
                codingFactoryOperation: codingFactoryOperation
            )

            historyRangeWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let erasRewardDistributionWrapper = try createErasRewardDistributionOperationWrapper(
                dependingOn: historyRangeWrapper.targetOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            erasRewardDistributionWrapper.allOperations
                .forEach {
                    $0.addDependency(historyRangeWrapper.targetOperation)
                    $0.addDependency(codingFactoryOperation)
                }

            let validatorsWrapper = validatorsResolutionFactory
                .createResolutionOperation(for: selectedAccountAddress)

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

            let ledgerInfos: CompoundOperationWrapper<[DyStakingLedger]> =
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
                dependingOn: eraInfoOperation,
                erasRewardOperation: erasRewardDistributionWrapper.targetOperation,
                historyRangeOperation: historyRangeWrapper.targetOperation,
                identityOperation: identityWrapper.targetOperation
            )

            payoutOperation.addDependency(eraInfoOperation)
            payoutOperation.addDependency(identityWrapper.targetOperation)
            payoutOperation.addDependency(erasRewardDistributionWrapper.targetOperation)
            payoutOperation.addDependency(historyRangeWrapper.targetOperation)

            let overviewOperations = [codingFactoryOperation] + historyRangeWrapper.allOperations
                + erasRewardDistributionWrapper.allOperations
            let validatorsResolutionOperations = validatorsWrapper.allOperations
                + controllersWrapper.allOperations + ledgerInfos.allOperations
                + [unclaimedErasByStashOperation]
            let validatorsAndEraInfoOperations = exposuresByEraWrapper.allOperations
                + prefsByEraWrapper.allOperations + identityWrapper.allOperations
                + [eraInfoOperation]

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
