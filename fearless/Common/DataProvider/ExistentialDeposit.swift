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
        switch chainAsset.chainAssetType {
        case .normal, .ormlChain:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeCodingService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        case .ormlAsset, .foreignAsset, .stableAssetPoolToken:
            fetchOrmlExistentialDeposit(chainAsset: chainAsset, completion: completion)
        }
    }

    // MARK: - Private methods

    private func fetchOrmlExistentialDeposit(
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
