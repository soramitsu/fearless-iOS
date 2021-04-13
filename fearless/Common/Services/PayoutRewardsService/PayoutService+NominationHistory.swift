import RobinHood
import FearlessUtils
import BigInt

extension PayoutRewardsService {
    func createNominationHistoryOperation(
        nominatorAccount: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<Set<String>> {
        try fetchControllersByStakingModule(
            nominatorStashAccount: nominatorAccount,
            chain: chain,
            subscanOperationFactory: subscanOperationFactory
        )
//        let controllersByStaking = try fetchControllersByStakingModule(
//            nominatorStashAccount: nominatorStashAccount,
//            chain: chain,
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue
//        )
//
//        let controllersByUtility = try fetchControllersByUtilityModule(
//            nominatorStashAccount: nominatorStashAccount,
//            chain: chain,
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue)
//
//        let setOfControllersWhichCouldEverMakeNominations =
//            controllersByStaking.union(controllersByUtility)
//
//        let validatorsByNominate = try fetchValidatorsByNominate(
//            controllers: setOfControllersWhichCouldEverMakeNominations,
//            chain: chain,
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue)
//
//        let validatorsByBatch = try fetchValidatorsByBatch(
//            controllers: setOfControllersWhichCouldEverMakeNominations,
//            chain: chain,
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue)
//
//        let validatorIdsSet = validatorsByNominate.union(validatorsByBatch)
    }

    private func fetchControllersByStakingModule(
        nominatorStashAccount _: String,
        chain: Chain,
        subscanOperationFactory: SubscanOperationFactoryProtocol
    ) throws -> CompoundOperationWrapper<Set<String>> {
        let bondWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "staking",
            address: selectedAccountAddress,
            callName: "bond",
            subscanOperationFactory: subscanOperationFactory
        )

        let setControllerWrapper = try createFetchExtrinsicsDataOperation(
            moduleName: "staking",
            address: selectedAccountAddress,
            callName: "set_controller",
            subscanOperationFactory: subscanOperationFactory
        )

        let mergeOperation = ClosureOperation<Set<String>> {
            guard
                let bondExtrinsics = try bondWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics,
                let setControllerExtrinsics = try setControllerWrapper.targetOperation.extractNoCancellableResultData()
                .extrinsics
            else {
                throw PayoutError.unknown
            }
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

//
//    private func fetchControllersByUtilityModule(
//        nominatorStashAccount: String,
//        chain: Chain,
//        subscanOperationFactory: SubscanOperationFactoryProtocol,
//        queue: OperationQueue
//    ) throws -> Set<String> {
//        let batchControllers = try fetchExtrinsicsParams(
//            moduleName: "utility",
//            address: nominatorStashAccount,
//            callName: "batch",
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue)
//
//        let batchAllControllers = try fetchExtrinsicsParams(
//            moduleName: "utility",
//            address: nominatorStashAccount,
//            callName: "batch_all",
//            subscanOperationFactory: subscanOperationFactory,
//            queue: queue)
//
//        let controllers = (batchControllers + batchAllControllers)
//            .compactMap { SubscanFindControllersBatchCall(callArgs: $0, chain: chain) }
//            .flatMap { $0.controllers }
//        return Set(controllers)
//    }
//
//    private func fetchValidatorsByNominate(
//        controllers: Set<String>,
//        chain: Chain,
//        subscanOperationFactory: SubscanOperationFactoryProtocol,
//        queue: OperationQueue
//    ) throws -> Set<String> {
//        let validators = controllers
//            .compactMap { address in
//                try? fetchExtrinsicsParams(
//                    moduleName: "staking",
//                    address: address,
//                    callName: "nominate",
//                    subscanOperationFactory: subscanOperationFactory,
//                    queue: queue
//                )
//                .compactMap { SubscanNominateCall(callArgs: $0, chain: chain) }
//                .map(\.validatorAddresses)
//            }
//            .flatMap { $0 }
//            .flatMap { $0 }
//        return Set(validators)
//    }
//
//    private func fetchValidatorsByBatch(
//        controllers: Set<String>,
//        chain: Chain,
//        subscanOperationFactory: SubscanOperationFactoryProtocol,
//        queue: OperationQueue
//    ) throws -> Set<String> {
//        let nominatorsBatch = controllers
//            .compactMap { address -> [String] in
//                let batch = try? fetchExtrinsicsParams(
//                    moduleName: "utility",
//                    address: address,
//                    callName: "batch",
//                    subscanOperationFactory: subscanOperationFactory,
//                    queue: queue
//                )
//
//                let batchAll = try? fetchExtrinsicsParams(
//                    moduleName: "utility",
//                    address: address,
//                    callName: "batch_all",
//                    subscanOperationFactory: subscanOperationFactory,
//                    queue: queue
//                )
//
//                return ((batch ?? []) + (batchAll ?? []))
//                    .compactMap { SubscanFindValidatorsBatchCall(callArgs: $0, chain: chain) }
//                    .flatMap(\.validatorAddresses)
//            }
//            .flatMap { $0 }
//
//        return Set(nominatorsBatch)
//    }

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

        let url = WalletAssetId.westend.subscanUrl!
            .appendingPathComponent(SubscanApi.extrinsics)
        let fetchOperation = subscanOperationFactory
            .fetchExtrinsicsOperation(url, info: extrinsicsInfo)

        return CompoundOperationWrapper(targetOperation: fetchOperation)
    }
}
