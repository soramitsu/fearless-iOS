import RobinHood
import FearlessUtils
import BigInt
import IrohaCrypto

extension PayoutRewardsService {
    func createControllersStep6Operation(
        nominatorStashAddress: String
    ) -> CompoundOperationWrapper<Set<AccountId>> {
        let controllersByStakingOperation =
            createControllersByStakingOperation(nominatorStashAccount: nominatorStashAddress)

        let controllersByUtilityOperation =
            createControllersByUtilityOperation(nominatorStashAccount: nominatorStashAddress)

        let mergeOperation = ClosureOperation<Set<AccountId>> {
            let stakingIds = try controllersByStakingOperation
                .targetOperation.extractNoCancellableResultData()
            let batchIds = try controllersByUtilityOperation
                .targetOperation.extractNoCancellableResultData()

            return stakingIds.union(batchIds)
        }

        let dependencies = controllersByStakingOperation.allOperations + controllersByUtilityOperation.allOperations
        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    private func createControllersByStakingOperation(nominatorStashAccount: String)
        -> CompoundOperationWrapper<Set<AccountId>> {
        let bondOperation = createSubscanQueryOperation(
            address: nominatorStashAccount,
            moduleName: "staking",
            callName: "bond",
            mapper: AnyMapper(mapper: ControllerMapper()),
            reducer: AnyReducer(reducer: ControllersReducer())
        )

        let setControllerOperation = createSubscanQueryOperation(
            address: nominatorStashAccount,
            moduleName: "staking",
            callName: "set_controller",
            mapper: AnyMapper(mapper: ControllerMapper()),
            reducer: AnyReducer(reducer: ControllersReducer())
        )

        let mergeOperation = ClosureOperation<Set<AccountId>> {
            let bondIds = try bondOperation.extractNoCancellableResultData()
            let setControllerIds = try setControllerOperation.extractNoCancellableResultData()

            return bondIds.union(setControllerIds)
        }

        let dependencies = [bondOperation, setControllerOperation]
        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    private func createControllersByUtilityOperation(
        nominatorStashAccount: String
    ) -> CompoundOperationWrapper<Set<Data>> {
        let controllerMapper = AnyMapper(mapper: ControllerMapper())

        let batchOperation = createSubscanQueryOperation(
            address: nominatorStashAccount,
            moduleName: "utility",
            callName: "batch",
            mapper: AnyMapper(mapper: BatchMapper(innerMapper: controllerMapper)),
            reducer: AnyReducer(reducer: ControllersListReducer())
        )

        let batchAllOperation = createSubscanQueryOperation(
            address: nominatorStashAccount,
            moduleName: "utility",
            callName: "batch_all",
            mapper: AnyMapper(mapper: BatchMapper(innerMapper: controllerMapper)),
            reducer: AnyReducer(reducer: ControllersListReducer())
        )

        let mergeOperation = ClosureOperation<Set<AccountId>> {
            let batchIds = try batchOperation.extractNoCancellableResultData()
            let batchAllIds = try batchAllOperation.extractNoCancellableResultData()

            return batchIds.union(batchAllIds)
        }

        let dependencies = [batchOperation, batchAllOperation]
        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    func createFindValidatorsOperation(
        controllers: Set<AccountId>
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

    private func createSubscanQueryOperation<T>(
        address: String,
        moduleName: String,
        callName: String,
        mapper: AnyMapper<JSON, T>,
        reducer: AnyReducer<T, Set<AccountId>>
    ) -> BaseOperation<Set<AccountId>> {
        let url = subscanBaseURL
            .appendingPathComponent(SubscanApi.extrinsics)

        let params = SubscanQueryParams(address: address, moduleName: moduleName, callName: callName)

        return SubscanQueryService(
            url: url,
            params: params,
            mapper: mapper,
            reducer: reducer,
            initialResultValue: [],
            subscanOperationFactory: subscanOperationFactory,
            operationManager: operationManager
        ).longrunOperation()
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
