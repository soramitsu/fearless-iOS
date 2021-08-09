import Foundation
import RobinHood
import FearlessUtils
import IrohaCrypto

final class PayoutValidatorsForNominatorFactory {
    let chain: Chain
    let subscanBaseURL: URL
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        chain: Chain,
        subscanBaseURL: URL,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.subscanBaseURL = subscanBaseURL
        self.subscanOperationFactory = subscanOperationFactory
        self.operationManager = operationManager
    }

    private func createControllersQueryWrapper(
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

    private func createValidatorsQueryWrapper(
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

extension PayoutValidatorsForNominatorFactory: PayoutValidatorsFactoryProtocol {
    func createResolutionOperation(
        for address: AccountAddress,
        dependingOn historyRangeOperation: BaseOperation<ChainHistoryRange>
    ) -> CompoundOperationWrapper<[AccountId]> {
        // TODO: delete localhost
        let source = SQEraStakersInfoSource(url: URL(string: "http://localhost:3000/")!, address: address)
        let operation = source.fetch {
            try? historyRangeOperation.extractNoCancellableResultData()
        }
        operation.addDependency(operations: [historyRangeOperation])

        return operation
    }
}

struct SQEraValidatorInfo {
    let address: String
    let era: String
    let total: String
    let own: String
    let others: [SQIndividualExposure]

    init?(from json: JSON) {
        guard
            let era = json.era?.stringValue,
            let address = json.address?.stringValue,
            let total = json.total?.stringValue,
            let own = json.own?.stringValue,
            let others = json.others?.arrayValue?.compactMap({ SQIndividualExposure(from: $0) })
        else { return nil }

        self.era = era
        self.address = address
        self.total = total
        self.own = own
        self.others = others
    }
}

struct SQIndividualExposure {
    let who: String
    let value: String

    init?(from json: JSON) {
        guard
            let who = json.who?.stringValue,
            let value = json.value?.stringValue
        else { return nil }
        self.who = who
        self.value = value
    }
}

final class SQEraStakersInfoSource {
    let url: URL
    let address: AccountAddress

    init(url: URL, address: AccountAddress) {
        self.url = url
        self.address = address
    }

    func fetch(historyRange: @escaping () -> ChainHistoryRange?) -> CompoundOperationWrapper<[AccountId]> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let erasRange = historyRange()?.erasRange
            let params = self.requestParams(accountAddress: self.address, erasRange: erasRange)
            let info = JSON.dictionaryValue(["query": JSON.stringValue(params)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<[AccountId]> { data in
            guard let resultData = try? JSONDecoder().decode(JSON.self, from: data) else { return [] }

            let factory = SS58AddressFactory()
            guard
                let nodes = resultData.data?.query?.eraValidatorInfos?.nodes?.arrayValue
            else { return [AccountId]() }

            let validators = nodes
                .compactMap { SQEraValidatorInfo(from: $0) }
                .compactMap { validatorInfo -> AccountAddress? in
                    let contains = validatorInfo.others.contains(where: { $0.who == self.address })
                    return contains ? validatorInfo.address : nil
                }
                .compactMap { accountAddress -> AccountId? in
                    try? factory.accountId(from: accountAddress)
                }

            return validators
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func requestParams(accountAddress: AccountAddress, erasRange: [EraIndex]?) -> String {
        let eraFilter: String = {
            guard let range = erasRange, range.count >= 2 else { return "" }
            return "era:{greaterThanOrEqualTo: \"\(range.first!)\", lessThanOrEqualTo: \"\(range.last!)\"},"
        }()

        return """
        {
          query {
            eraValidatorInfos(
              filter:{
                \(eraFilter)
                others:{contains:[{who:\"\(accountAddress)\"}]}
              }
            ) {
              nodes {
                id
                address
                era
                total
                own
                others
              }
            }
          }
        }
        """
    }
}
