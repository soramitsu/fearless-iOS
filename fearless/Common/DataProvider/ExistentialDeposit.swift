import Foundation
import BigInt
import RobinHood
import FearlessUtils

protocol ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    )
}

final class ExistentialDepositService: RuntimeConstantFetching, ExistentialDepositServiceProtocol {
    // MARK: - Private properties

    private let operationManager: OperationManagerProtocol
    private let chainRegistry: ChainRegistryProtocol
    private let chainId: ChainModel.Id

    // MARK: - Constructor

    init(
        operationManager: OperationManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        chainId: ChainModel.Id
    ) {
        self.operationManager = operationManager
        self.chainRegistry = chainRegistry
        self.chainId = chainId
    }

    // MARK: - Public methods

    func fetchExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            completion(.failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

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
                runtimeCodingService: runtimeService,
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
            .stable:
            fetchSubAssetsExistentialDeposit(chainAsset: chainAsset, completion: completion)
        case .equilibrium:
            fetchConstant(
                for: .equilibriumExistentialDeposit,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        }
    }

    // MARK: - Private methods

    private func fetchSubAssetsExistentialDeposit(
        chainAsset: ChainAsset,
        completion: @escaping (Result<BigUInt, Error>) -> Void
    ) {
        guard let connection = chainRegistry.getConnection(for: chainId) else {
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
}
