import Foundation
import BigInt
import RobinHood
import FearlessUtils

protocol ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(completion: @escaping (Result<BigUInt, Error>) -> Void)
}

enum ExistentialDepositCurrencyId {
    case token(tokenSymbol: String)
    case foreignAsset(tokenSymbol: UInt16)

    init?(from currencyId: CurrencyId?) {
        guard let currencyId = currencyId else {
            return nil
        }
        switch currencyId {
        case let .token(symbol):
            guard let symbol = symbol?.symbol else {
                return nil
            }
            self = .token(tokenSymbol: symbol.uppercased())
        case let .foreignAsset(foreignAsset):
            guard let uint = UInt16(foreignAsset) else {
                return nil
            }
            self = .foreignAsset(tokenSymbol: uint)
        }
    }
}

extension ExistentialDepositCurrencyId: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .token(symbol):
            try container.encode(symbol, forKey: .token)
        case let .foreignAsset(foreignAsset):
            try container.encode(foreignAsset, forKey: .foreignAsset)
        }
    }
}

final class ExistentialDepositService: RuntimeConstantFetching, ExistentialDepositServiceProtocol {
    // MARK: - Private properties

    private let chainAsset: ChainAsset
    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let engine: JSONRPCEngine

    // MARK: - Constructor

    init(
        chainAsset: ChainAsset,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine
    ) {
        self.chainAsset = chainAsset
        self.runtimeCodingService = runtimeCodingService
        self.operationManager = operationManager
        self.engine = engine
    }

    // MARK: - Public methods

    func fetchExistentialDeposit(completion: @escaping (Result<BigUInt, Error>) -> Void) {
        switch chainAsset.chainAssetType {
        case .normal, .ormlChain:
            fetchConstant(
                for: .existentialDeposit,
                runtimeCodingService: runtimeCodingService,
                operationManager: operationManager
            ) { result in
                completion(result)
            }
        case .ormlAsset, .foreignAsset:
            fetchOrmlExistentialDeposit(completion: completion)
        }
    }

    // MARK: - Private methods

    private func fetchOrmlExistentialDeposit(completion: @escaping (Result<BigUInt, Error>) -> Void) {
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
