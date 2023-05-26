import Foundation
import BigInt
import RobinHood
import SSFUtils

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
            .stable:
            fetchSubAssetsExistentialDeposit(chainAsset: chainAsset, completion: completion)
        case .equilibrium:
            fetchConstant(
                for: .equilibriumExistentialDeposit,
                runtimeCodingService: runtimeCodingService,
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
}
