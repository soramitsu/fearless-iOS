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
    ) throws -> CompoundOperationWrapper<[AccountId]> {
        let addressFactory = SS58AddressFactory()

        let validatorsOperations: [[BaseOperation<Set<AccountId>>]] =
            try controllers.map { controller in
                let address = try addressFactory
                    .addressFromAccountId(data: controller, type: chain.addressType)

                let mapper = AnyMapper(mapper: NominateMapper())

                let validatorsByNominate = createSubscanQueryOperation(
                    address: address,
                    moduleName: "staking",
                    callName: "nominate",
                    mapper: mapper,
                    reducer: AnyReducer(reducer: NominationsReducer())
                )

                let validatorsByBatch = createSubscanQueryOperation(
                    address: address,
                    moduleName: "utility",
                    callName: "batch",
                    mapper: AnyMapper(mapper: BatchMapper(innerMapper: mapper)),
                    reducer: AnyReducer(reducer: NominationsListReducer())
                )

                let validatorsByBatchAll = createSubscanQueryOperation(
                    address: address,
                    moduleName: "utility",
                    callName: "batch_all",
                    mapper: AnyMapper(mapper: BatchMapper(innerMapper: mapper)),
                    reducer: AnyReducer(reducer: NominationsListReducer())
                )

                return [validatorsByNominate, validatorsByBatch, validatorsByBatchAll]
            }

        let dependecies = validatorsOperations.flatMap { $0 }

        let mergeOperation = ClosureOperation<[Data]> {
            let allSets = try dependecies.map { try $0.extractNoCancellableResultData() }

            let resultSet = allSets.reduce(into: Set<AccountId>()) { result, item in
                result = result.union(item)
            }

            return Array(resultSet)
        }

        dependecies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependecies
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
}
