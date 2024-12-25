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

    func fetchExistentialDeposit(
        chainAsset: ChainAsset
    ) async throws -> BigUInt
}

final class ExistentialDepositService: RuntimeConstantFetching, ExistentialDepositServiceProtocol {
    // MARK: - Private properties

    private let operationManager: OperationManagerProtocol
    private let chainRegistry: ChainRegistryProtocol

    // MARK: - Constructor

    init(
        operationManager: OperationManagerProtocol,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.operationManager = operationManager
        self.chainRegistry = chainRegistry
    }

    // MARK: - Public methods

    func fetchExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            completion(.failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        switch chainAsset.chainAssetType.substrateAssetType {
        case .equilibrium:
            fetchConstant(
                for: .equilibriumExistentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        default:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        }
    }

    func fetchExistentialDeposit(
        chainAsset: ChainAsset
    ) async throws -> BigUInt {
        try await withUnsafeThrowingContinuation { continuation in
            fetchExistentialDeposit(chainAsset: chainAsset) { result in
                switch result {
                case let .success(success):
                    continuation.resume(returning: success)
                case let .failure(failure):
                    continuation.resume(throwing: failure)
                }
            }
        }
    }

    // MARK: - Private methods

    private func fetchSubAssetsExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            completion(.failure(ChainRegistryError.connectionUnavailable))
            return
        }

        guard let parameter = ExistentialDepositCurrencyId(from: chainAsset.currencyId) else {
            return
        }

        let callOperation = JSONRPCOperation<[ExistentialDepositCurrencyId], String>(
            engine: connection,
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
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            completion(.failure(ChainRegistryError.connectionUnavailable))
            return
        }
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            completion(.failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }
        guard let currencyId = chainAsset.asset.currencyId else {
            completion(.failure(ConvenienceError(error: "missing currency id \(chainAsset.debugName)")))
            return
        }
        let assetsDetailsPath = StorageCodingPath.assetsAssetDetail
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<AssetDetails>]> = requestFactory.queryItems(
            engine: connection,
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
