import Foundation
import BigInt
import RobinHood
import SSFUtils
import SSFModels

protocol ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    )
}

final class ExistentialDepositService: RuntimeConstantFetching, ExistentialDepositServiceProtocol {
    // MARK: - Private properties

    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let engine: JSONRPCEngine

    // MARK: - Constructor

    init(
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine
    ) {
        self.runtimeCodingService = runtimeCodingService
        self.operationManager = operationManager
        self.engine = engine
    }

    // MARK: - Public methods

    func fetchExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        if
            let existentialDeposit = chainAsset.asset.existentialDeposit,
            let result = BigUInt(existentialDeposit) {
            completion(.success(result))
            return
        }

        switch chainAsset.chainAssetType {
        case .normal, .ormlChain, .soraAsset:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeCodingService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        case
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2:
            fetchSubAssetsExistentialDeposit(chainAsset: chainAsset, completion: completion)
        case .equilibrium:
            fetchConstant(
                for: .equilibriumExistentialDeposit,
                runtimeCodingService: runtimeCodingService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        case .assets:
            fetchAssetsExistentialDeposit(chainAsset: chainAsset, completion: completion)
        }
    }

    // MARK: - Private methods

    private func fetchSubAssetsExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let parameter = ExistentialDepositCurrencyId(from: chainAsset.currencyId) else {
            return
        }

        let callOperation = JSONRPCOperation<[ExistentialDepositCurrencyId], String>(
            engine: engine,
            method: RPCMethod.existentialDeposit,
            parameters: [parameter]
        )

        callOperation.completionBlock = {
            do {
                let response = try callOperation.extractNoCancellableResultData()
                guard let deposit = BigUInt.fromHexString(response) else {
                    return
                }

                DispatchQueue.main.async {
                    completion(.success(deposit))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [callOperation], in: .transient)
    }

    private func fetchAssetsExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let currencyId = chainAsset.asset.currencyId else {
            completion(.failure(ConvenienceError(error: "missing currency id \(chainAsset.debugName)")))
            return
        }
        let assetsDetailsPath = StorageCodingPath.assetsAssetDetail
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<AssetDetails>]> = requestFactory.queryItems(
            engine: engine,
            keyParams: { [StringScaleMapper(value: currencyId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: assetsDetailsPath
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        fetchWrapper.targetOperation.completionBlock = {
            do {
                let details = try fetchWrapper.targetOperation.extractNoCancellableResultData().first?.value

                DispatchQueue.main.async {
                    completion(.success(details?.minBalance ?? .zero))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }

        let operations = [codingFactoryOperation] + fetchWrapper.allOperations
        operationManager.enqueue(operations: operations, in: .transient)
    }
}
