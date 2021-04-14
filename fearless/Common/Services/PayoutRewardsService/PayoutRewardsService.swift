import Foundation
import FearlessUtils
import RobinHood
import BigInt
import IrohaCrypto

final class PayoutRewardsService: PayoutRewardsServiceProtocol {
    func update(to _: Chain) {}

    let selectedAccountAddress: String
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let logger: LoggerProtocol?

    let syncQueue = DispatchQueue(
        label: "jp.co.fearless.payout.\(UUID().uuidString)",
        qos: .userInitiated
    )

    private(set) var activeEra: UInt32?
    private let chain: Chain
    private var isActive: Bool = false

    init(
        selectedAccountAddress: String,
        chain: Chain,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.runtimeCodingService = runtimeCodingService
        self.engine = engine
        self.operationManager = operationManager
        self.providerFactory = providerFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.logger = logger
    }

    // swiftlint:disable function_body_length
    func fetchPayoutRewards(completion: @escaping PayoutRewardsClosure) {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        do {
            let steps1to3OperationWrapper = try createSteps1To3OperationWrapper(
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            let steps4And5OperationWrapper = try createSteps4And5OperationWrapper(
                dependingOn: steps1to3OperationWrapper.targetOperation,
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )
            steps4And5OperationWrapper.allOperations
                .forEach { $0.addDependency(steps1to3OperationWrapper.targetOperation) }

            let nominationHistoryStep6Controllers = try createControllersStep6Operation(
                nominatorAccount: selectedAccountAddress,
                chain: chain,
                subscanOperationFactory: subscanOperationFactory
            )

            nominationHistoryStep6Controllers.targetOperation.completionBlock = {
                do {
                    let controllersSet = try nominationHistoryStep6Controllers
                        .targetOperation.extractNoCancellableResultData()

                    let validatorsWrapper = try self.createFindValidatorsOperation(
                        controllers: controllersSet,
                        chain: self.chain,
                        subscanOperationFactory: self.subscanOperationFactory
                    )

                    let controllersWrapper = try self.createControllersByValidatorStashOperation(
                        dependingOn: validatorsWrapper.targetOperation,
                        chain: self.chain,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    controllersWrapper.allOperations
                        .forEach { $0.addDependency(validatorsWrapper.targetOperation) }

                    let ledgerInfos = try self.createLedgerInfoOperation(
                        dependingOn: controllersWrapper.targetOperation,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    ledgerInfos.allOperations
                        .forEach { $0.addDependency(controllersWrapper.targetOperation) }

                    let unclaimedErasByStashOperation = try self.createUnclaimedEraByStashOperation(
                        ledgerInfoOperation: ledgerInfos.targetOperation,
                        steps1to3Operation: steps1to3OperationWrapper.targetOperation
                    )
                    unclaimedErasByStashOperation.allOperations.forEach {
                        $0.addDependency(ledgerInfos.targetOperation)
                        $0.addDependency(steps1to3OperationWrapper.targetOperation)
                    }

                    let exposureByEraOperation = try self.validatorExposureGroupedByEraOperation(
                        dependingOn: unclaimedErasByStashOperation.targetOperation,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    exposureByEraOperation.allOperations
                        .forEach { $0.addDependency(unclaimedErasByStashOperation.targetOperation) }

                    let prefsByEraOperation = try self.validatorPrefsGroupedByEraOperation(
                        dependingOn: unclaimedErasByStashOperation.targetOperation,
                        engine: self.engine,
                        codingFactoryOperation: codingFactoryOperation
                    )
                    prefsByEraOperation.allOperations
                        .forEach { $0.addDependency(unclaimedErasByStashOperation.targetOperation) }

                    let rewardPerValidatorOperation = try self.calculateRewardPerValidatorOperation(
                        steps4And5Oparation: steps4And5OperationWrapper.targetOperation,
                        ledgerInfoOperation: ledgerInfos.targetOperation,
                        chain: self.chain
                    )
                    rewardPerValidatorOperation.allOperations.forEach {
                        $0.addDependency(steps4And5OperationWrapper.targetOperation)
                        $0.addDependency(ledgerInfos.targetOperation)
                    }

                    let rewardOperation = try self.calculateRewardOperation(
                        rewardPerValidatorOparation: rewardPerValidatorOperation.targetOperation,
                        exposureByEraOperation: exposureByEraOperation.targetOperation,
                        prefsByEraOperation: prefsByEraOperation.targetOperation,
                        nominatorStashAccount: self.selectedAccountAddress,
                        chain: self.chain
                    )
                    rewardOperation.allOperations.forEach {
                        $0.addDependency(rewardPerValidatorOperation.targetOperation)
                        $0.addDependency(exposureByEraOperation.targetOperation)
                        $0.addDependency(prefsByEraOperation.targetOperation)
                    }

                    rewardOperation.targetOperation.completionBlock = {
                        do {
                            let rewards = try rewardOperation
                                .targetOperation.extractNoCancellableResultData()
                            let payoutItems = rewards
                                .reduce(into: [PayoutItem]()) { items, rewardsDict in
                                    let item = PayoutItem(
                                        validatorAccount: rewardsDict.key,
                                        rewardsByEra: rewardsDict.value
                                    )
                                    items.append(item)
                                }
                            completion(.success(payoutItems))
                        } catch {
                            completion(.failure(error))
                        }
                    }

                    let operations: [Operation] =
                        validatorsWrapper.allOperations
                            + controllersWrapper.allOperations
                            + ledgerInfos.allOperations
                            + unclaimedErasByStashOperation.allOperations
                            + exposureByEraOperation.allOperations
                            + prefsByEraOperation.allOperations
                            + rewardPerValidatorOperation.allOperations
                            + rewardOperation.allOperations

                    self.operationManager.enqueue(
                        operations: operations,
                        in: .transient
                    )
                } catch {
                    completion(.failure(error))
                }
            }

            let operations = [codingFactoryOperation]
                + steps1to3OperationWrapper.allOperations
                + steps4And5OperationWrapper.allOperations
                + nominationHistoryStep6Controllers.allOperations

            operationManager.enqueue(operations: operations, in: .transient)
        } catch {
            logger?.debug(error.localizedDescription)
            completion(.failure(error))
        }
    }

    func calculateRewardOperation(
        rewardPerValidatorOparation: BaseOperation<[Data: [EraIndex: Decimal]]>,
        exposureByEraOperation: BaseOperation<[EraIndex: [(Data, ValidatorExposure)]]>,
        prefsByEraOperation: BaseOperation<[EraIndex: [(Data, ValidatorPrefs)]]>,
        nominatorStashAccount: String,
        chain: Chain
    ) throws -> CompoundOperationWrapper<[Data: [(EraIndex, Decimal)]]> {
        let ownAccountId = try SS58AddressFactory().accountId(
            fromAddress: nominatorStashAccount,
            type: chain.addressType
        )

        let mergeOperation = ClosureOperation<[Data: [(EraIndex, Decimal)]]> {
            let rewardPerValidator = try rewardPerValidatorOparation
                .extractNoCancellableResultData()
            let exposureByEra = try exposureByEraOperation
                .extractNoCancellableResultData()
            let prefsByEra = try prefsByEraOperation
                .extractNoCancellableResultData()

            return rewardPerValidator
                .reduce(into: [Data: [(EraIndex, Decimal)]]()) { dict, item in
                    let (stash, validatorRewardPerEra) = (item.key, item.value)

                    let nominatorRewardByEra = validatorRewardPerEra
                        .reduce(into: [(EraIndex, Decimal)]()) { array, tuple in
                            let (era, validatorRewardPerEra) = tuple

                            guard
                                let prefs = prefsByEra[era],
                                let validatorComission = prefs
                                .first(where: { $0.0 == stash })
                                .map(\.1.commission)
                                .map({ Decimal.fromSubstratePerbill(value: $0)! }),
                                let exposure = exposureByEra[era],
                                let maybeTotalStake = exposure
                                .first(where: { $0.0 == stash })
                                .map(\.1.total)
                                .map({ Decimal.fromSubstrateAmount(
                                    $0,
                                    precision: chain.addressType.precision
                                ) }),
                                let totalStake = maybeTotalStake,
                                let maybeMominatorStake = exposure
                                .first(where: { $0.0 == stash })
                                .map(\.1)
                                .map({ exposure -> Decimal? in
                                    exposure.others
                                        .first(where: { $0.who == ownAccountId })
                                        .map { Decimal.fromSubstrateAmount(
                                            $0.value,
                                            precision: chain.addressType.precision
                                        )! }
                                }),
                                let nominatorStake = maybeMominatorStake
                            else {
                                return
                            }
                            let nominatorReward = validatorRewardPerEra
                                * (Decimal(1) - validatorComission)
                                * nominatorStake / totalStake

                            array.append((era, nominatorReward))
                        }

                    if !nominatorRewardByEra.isEmpty {
                        dict[stash] = nominatorRewardByEra
                    }
                }
        }

        return CompoundOperationWrapper(targetOperation: mergeOperation)
    }

    func calculateRewardPerValidatorOperation(
        steps4And5Oparation: BaseOperation<PayoutSteps4And5Result>,
        ledgerInfoOperation: BaseOperation<[DyStakingLedger]>,
        chain: Chain
    ) throws -> CompoundOperationWrapper<[Data: [EraIndex: Decimal]]> {
        let mergeOperation = ClosureOperation<[Data: [EraIndex: Decimal]]> {
            let steps4And5Result = try steps4And5Oparation
                .extractNoCancellableResultData()
            let ledgerInfo = try ledgerInfoOperation.extractNoCancellableResultData()
            let stashes = ledgerInfo.map(\.stash)

            let totalRewardsByEra = steps4And5Result.totalValidatorRewardByEra
            let pointsByEra = steps4And5Result.validatorPointsDistributionByEra

            return stashes
                .reduce(into: [Data: [EraIndex: Decimal]]()) { dict, stash in
                    let validatorRewardByEra = totalRewardsByEra
                        .reduce(into: [EraIndex: Decimal]()) { dict, totalRewardByEra in
                            let (era, totalReward) = totalRewardByEra
                            guard
                                let rewardPoints = pointsByEra[era],
                                let totalRewardDecimal = Decimal.fromSubstrateAmount(
                                    totalReward,
                                    precision: chain.addressType.precision
                                ),
                                let validatorPoint = rewardPoints
                                .individual
                                .first(where: { $0.accountId == stash })
                                .map(\.rewardPoint)
                            else { return }

                            let ratio = Decimal(validatorPoint) / Decimal(rewardPoints.total)

                            let validatorReward = totalRewardDecimal * ratio
                            dict[era] = validatorReward
                        }

                    dict[stash] = validatorRewardByEra
                }
        }

        return CompoundOperationWrapper(targetOperation: mergeOperation)
    }
}
