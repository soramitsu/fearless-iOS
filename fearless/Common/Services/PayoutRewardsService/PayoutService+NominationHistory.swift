import RobinHood
import FearlessUtils
import BigInt
import IrohaCrypto

extension PayoutRewardsService {
    func createControllersStep6Operation(
        nominatorAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<Set<String>> {
        let controllersByStakingOperation = try createControllersByStakingOperation(
            nominatorStashAccount: nominatorAccount,
            chain: chain,
            subscanOperationFactory: subscanOperationFactory
        )

        let controllersByUtilityOperation = try createControllersByUtilityOperation(
            nominatorStashAccount: nominatorAccount,
            chain: chain,
            subscanOperationFactory: subscanOperationFactory
        )

        let mergeOperation = ClosureOperation<Set<String>> {
            let controllersByStaking = try controllersByStakingOperation.targetOperation
                .extractNoCancellableResultData()
            let controllersByUtility = try controllersByUtilityOperation.targetOperation
                .extractNoCancellableResultData()

            let controllersWhichCouldEverMakeNominations =
                controllersByStaking.union(controllersByUtility)
            return controllersWhichCouldEverMakeNominations
        }
        let mergeOperationDependencies =
            controllersByStakingOperation.allOperations + controllersByUtilityOperation.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    private func createControllersByStakingOperation(
        nominatorStashAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<Set<String>> {
        let bondWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "staking",
            address: nominatorStashAccount,
            callName: "bond",
            subscanOperationFactory: subscanOperationFactory
        )

        let setControllerWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "staking",
            address: nominatorStashAccount,
            callName: "set_controller",
            subscanOperationFactory: subscanOperationFactory
        )

        let mergeOperation = ClosureOperation<Set<String>> {
            let bondExtrinsics = try bondWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics ?? []
            let setControllerExtrinsics = try setControllerWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics ?? []

            let controllers = (bondExtrinsics + setControllerExtrinsics)
                .compactMap(\.params)
                .map { SubscanBondCall(callArgs: $0, chain: chain) }
                .compactMap { $0?.controller }

            return Set<String>(controllers)
        }
        let mergeOperationDependencies = bondWrapper.allOperations + setControllerWrapper.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    private func createControllersByUtilityOperation(
        nominatorStashAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<Set<String>> {
        let batchWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "utility",
            address: nominatorStashAccount,
            callName: "batch",
            subscanOperationFactory: subscanOperationFactory
        )

        let batchAllWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "utility",
            address: nominatorStashAccount,
            callName: "batch_all",
            subscanOperationFactory: subscanOperationFactory
        )

        let mergeOperation = ClosureOperation<Set<String>> {
            let batchExtrinsics = try batchWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics ?? []
            let batchAllExtrinsics = try batchAllWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics ?? []

            let controllers = (batchExtrinsics + batchAllExtrinsics)
                .compactMap(\.params)
                .map { SubscanFindControllersBatchCall(callArgs: $0, chain: chain) }
                .compactMap { $0?.controllers }
                .flatMap { $0 }

            return Set<String>(controllers)
        }
        let mergeOperationDependencies = batchWrapper.allOperations + batchAllWrapper.allOperations
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    func createFindValidatorsOperation(
        controllers: Set<String>,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<[Data]> {
        let validatorsByNominateWrappers = try controllers
            .map { address in
                try createFetchExtrinsicsDataOperation(
                    moduleName: "staking",
                    address: address,
                    callName: "nominate",
                    subscanOperationFactory: subscanOperationFactory
                )
            }

        let validatorsByBatchWrappers = try controllers
            .map { address in
                try createFetchExtrinsicsDataOperation(
                    moduleName: "utility",
                    address: address,
                    callName: "batch",
                    subscanOperationFactory: subscanOperationFactory
                )
            }

        let validatorsByBatchAllWrappers = try controllers
            .map { address in
                try createFetchExtrinsicsDataOperation(
                    moduleName: "utility",
                    address: address,
                    callName: "batch_all",
                    subscanOperationFactory: subscanOperationFactory
                )
            }

        let mergeOperation = ClosureOperation<[Data]> {
            let validatorsByNominate = try validatorsByNominateWrappers
                .map { try $0.targetOperation.extractNoCancellableResultData() }
                .compactMap { extrinsicsData -> [SubscanExtrinsicsItemData]? in
                    extrinsicsData.extrinsics
                }
                .flatMap { $0 }
                .compactMap(\.params)
                .compactMap { SubscanNominateCall(callArgs: $0, chain: chain) }
                .map(\.validatorAddresses)
                .flatMap { $0 }

            let validatorsBatch = try (validatorsByBatchWrappers + validatorsByBatchAllWrappers)
                .map { try $0.targetOperation.extractNoCancellableResultData() }
                .compactMap { extrinsicsData -> [SubscanExtrinsicsItemData]? in
                    extrinsicsData.extrinsics
                }
                .flatMap { $0 }
                .compactMap(\.params)
                .compactMap { SubscanFindValidatorsBatchCall(callArgs: $0, chain: chain) }
                .map(\.validatorAddresses)
                .flatMap { $0 }

            let validatorsSet = Set<String>(validatorsByNominate + validatorsBatch)

            let addressFactory = SS58AddressFactory()
            return try validatorsSet.map { try addressFactory.accountId(from: $0) }
        }

        let mergeOperationDependencies =
            (validatorsByNominateWrappers + validatorsByBatchWrappers + validatorsByBatchAllWrappers)
                .map(\.allOperations).flatMap { $0 }
        mergeOperationDependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: mergeOperationDependencies
        )
    }

    private func createFetchExtrinsicsDataOperation(
        moduleName: String,
        address: String,
        callName: String,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<SubscanExtrinsicsData> {
        let extrinsicsInfo = ExtrinsicsInfo(
            row: 100,
            page: 0,
            address: address,
            moduleName: moduleName,
            callName: callName
        )

        let url = subscanBaseURL
            .appendingPathComponent(SubscanApi.extrinsics)
        let fetchOperation = subscanOperationFactory
            .fetchExtrinsicsOperation(url, info: extrinsicsInfo)

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }
}
