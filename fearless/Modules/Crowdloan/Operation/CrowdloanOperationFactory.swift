import Foundation
import RobinHood
import FearlessUtils
import IrohaCrypto

protocol CrowdloanOperationFactoryProtocol {
    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: Chain
    ) -> CompoundOperationWrapper<[Crowdloan]>

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        address: AccountAddress,
        trieIndex: UInt32
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse>
}

final class CrowdloanOperationFactory {
    let operationManager: OperationManagerProtocol
    let requestOperationFactory: StorageRequestFactoryProtocol

    init(requestOperationFactory: StorageRequestFactoryProtocol, operationManager: OperationManagerProtocol) {
        self.requestOperationFactory = requestOperationFactory
        self.operationManager = operationManager
    }
}

extension CrowdloanOperationFactory: CrowdloanOperationFactoryProtocol {
    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain _: Chain
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let codingKeyFactory = StorageKeyFactory()

        let mapper = StorageKeySuffixMapper<StringScaleMapper<UInt32>>(
            type: SubstrateConstants.paraIdType,
            suffixLength: SubstrateConstants.paraIdLength,
            coderFactoryClosure: { try coderFactoryOperation.extractNoCancellableResultData() }
        )

        let paraIdsOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: { try codingKeyFactory.key(from: .crowdloanFunds) },
            mapper: AnyMapper(mapper: mapper)
        ).longrunOperation()

        paraIdsOperation.addDependency(coderFactoryOperation)

        let fundsOperation: CompoundOperationWrapper<[StorageResponse<CrowdloanFunds>]> =
            requestOperationFactory.queryItems(
                engine: connection,
                keyParams: {
                    try paraIdsOperation.extractNoCancellableResultData()
                },
                factory: {
                    try coderFactoryOperation.extractNoCancellableResultData()
                }, storagePath: .crowdloanFunds
            )

        fundsOperation.allOperations.forEach { $0.addDependency(paraIdsOperation) }

        let mapOperation = ClosureOperation<[Crowdloan]> {
            try fundsOperation.targetOperation.extractNoCancellableResultData().compactMap { response in
                guard let fundInfo = response.value, let paraId = mapper.map(input: response.key)?.value else {
                    return nil
                }

                return Crowdloan(paraId: paraId, fundInfo: fundInfo)
            }
        }

        mapOperation.addDependency(fundsOperation.targetOperation)

        let dependencies = [coderFactoryOperation, paraIdsOperation] + fundsOperation.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        address: AccountAddress,
        trieIndex: UInt32
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        let addressFactory = SS58AddressFactory()

        let storageKeyParam: () throws -> Data = {
            try addressFactory.accountId(from: address)
        }

        let childKeyParam: () throws -> Data = {
            let trieIndexEncoder = ScaleEncoder()
            try trieIndex.encode(scaleEncoder: trieIndexEncoder)
            let trieIndexData = trieIndexEncoder.encode()

            guard let childSuffix = try "crowdloan".data(using: .utf8).map({ $0 + trieIndexData })?.blake2b32() else {
                throw NetworkBaseError.badSerialization
            }

            guard let childKey = ":child_storage:default:".data(using: .utf8).map({ $0 + childSuffix }) else {
                throw NetworkBaseError.badSerialization
            }

            return childKey
        }

        let queryWrapper: CompoundOperationWrapper<ChildStorageResponse<CrowdloanContribution>> =
            requestOperationFactory.queryChildItem(
                engine: connection,
                storageKeyParam: storageKeyParam,
                childKeyParam: childKeyParam,
                factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                mapper: CrowdloanContributionMapper()
            )

        queryWrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let mappingOperation = ClosureOperation<CrowdloanContributionResponse> {
            let result = try queryWrapper.targetOperation.extractNoCancellableResultData()
            return CrowdloanContributionResponse(address: address, trieIndex: trieIndex, contribution: result.value)
        }

        mappingOperation.addDependency(queryWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [coderFactoryOperation] + queryWrapper.allOperations
        )
    }
}
