import Foundation
import FearlessUtils
import RobinHood
import BigInt

protocol EquilibriumTotalBalanceServiceDelegate: AnyObject {
    func handleEquilibrium(totalBalance: BigUInt)
}

protocol EquilibriumTotalBalanceServiceProtocol {
    func fetchTotalBalance(handler: EquilibriumTotalBalanceServiceDelegate)
}

final class EquilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol {
    // MARK: - Private properties

    private let wallet: MetaAccountModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let equiliriubChainAsset: ChainAsset
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol?
    private let engine: JSONRPCEngine?
    private let logger: LoggerProtocol

    private let lock = NSLock()

    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private var oraclePricesMap: [UInt64: BigUInt] = [:]

    private weak var delegate: EquilibriumTotalBalanceServiceDelegate?

    // MARK: - Constructor

    init(
        wallet: MetaAccountModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        equiliriubChainAsset: ChainAsset,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol?,
        engine: JSONRPCEngine?,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.equiliriubChainAsset = equiliriubChainAsset
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.engine = engine
        self.logger = logger
    }

    // MARK: - Public methods

    func fetchTotalBalance(handler: EquilibriumTotalBalanceServiceDelegate) {
        delegate = handler
        fetchOraclePrice()
        subscribeToAccountInfo()
    }

    // MARK: - Private methods

    private func calculateTotalBalance() {
        guard oraclePricesMap.isNotEmpty, accountInfos.isNotEmpty else {
            return
        }
        let request = equiliriubChainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return
        }
        let precision = Int16(equiliriubChainAsset.asset.precision)
        var equlibriumTotalBalance: BigUInt = .zero
        oraclePricesMap.forEach { key, price in
            guard let chainAsset = equiliriubChainAsset.chain.chainAssets.first(where: {
                $0.asset.currencyId == "\(key)"
            }) else {
                return
            }

            let uniqueKey = chainAsset.uniqueKey(accountId: accountId)
            guard let balance = accountInfos[uniqueKey] ?? nil else { return }

            let priceDecimal = Decimal
                .fromSubstrateAmount(price, precision: precision) ?? .zero
            let totalBalanceAssetDecimal = Decimal
                .fromSubstrateAmount(balance.data.free, precision: precision) ?? .zero
            var equlibriumTotalBalanceDecimal = Decimal
                .fromSubstrateAmount(equlibriumTotalBalance, precision: precision) ?? .zero

            let totalAssetBalance = priceDecimal * totalBalanceAssetDecimal
            equlibriumTotalBalanceDecimal += totalAssetBalance

            equlibriumTotalBalance = equlibriumTotalBalanceDecimal.toSubstrateAmount(precision: precision) ?? .zero
        }
        delegate?.handleEquilibrium(totalBalance: equlibriumTotalBalance)
    }

    private func subscribeToAccountInfo() {
        let request = equiliriubChainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return
        }
        accountInfoSubscriptionAdapter.subscribe(
            chainAsset: equiliriubChainAsset,
            accountId: accountId,
            handler: self,
            deliveryOn: .global()
        )
    }

    private func fetchOraclePrice() {
        guard
            let runtimeOperation = runtimeService?.fetchCoderFactoryOperation(),
            let engine = engine
        else {
            return
        }
        let fetchPriceOperation = createPriceWrapper(dependingOn: runtimeOperation, engine: engine)
        let mapOraclePriceOperation = createMapOraclePriceOperation(dependingOn: fetchPriceOperation)

        mapOraclePriceOperation.completionBlock = { [weak self] in
            guard let strongSelf = self else { return }
            let result = mapOraclePriceOperation.result
            switch result {
            case let .success(map):
                strongSelf.oraclePricesMap = map
                strongSelf.calculateTotalBalance()
            case let .failure(error):
                strongSelf.logger.error("\(error)")
            case .none:
                break
            }
        }

        let operations = [runtimeOperation] + fetchPriceOperation.allOperations + [mapOraclePriceOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func createMapOraclePriceOperation(
        dependingOn operation: CompoundOperationWrapper<[StorageResponse<EqOraclePricePoint>]>
    ) -> ClosureOperation<[UInt64: BigUInt]> {
        let mapOraclePriceOperation = ClosureOperation<[UInt64: BigUInt]> { [weak self] in
            guard let strongSelf = self else {
                return [:]
            }
            let oraclePrice = try operation.targetOperation.extractNoCancellableResultData()

            let map = oraclePrice.reduce([UInt64: BigUInt]()) { partialResult, storageResponse -> [UInt64: BigUInt] in
                var map = partialResult
                guard let value = storageResponse.value else {
                    return map
                }

                do {
                    let extractor = StorageKeyDataExtractor(storageKey: storageResponse.key)
                    let currencyId = try extractor.extractU64Parameter()
                    map[currencyId] = value.price
                } catch {
                    strongSelf.logger.error("\(error)")
                }
                return map
            }
            return map
        }

        mapOraclePriceOperation.addDependency(operation.targetOperation)
        return mapOraclePriceOperation
    }

    private func createPriceWrapper(
        dependingOn runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine
    ) -> CompoundOperationWrapper<[StorageResponse<EqOraclePricePoint>]> {
        let wrapper: CompoundOperationWrapper<[StorageResponse<EqOraclePricePoint>]> =
            storageRequestFactory.queryItemsByPrefix(
                engine: engine,
                keys: { [try StorageKeyFactory().key(from: .eqOraclePricePoint)] },
                factory: { try runtimeOperation.extractNoCancellableResultData() },
                storagePath: .eqOraclePricePoint
            )

        wrapper.allOperations.forEach { $0.addDependency(runtimeOperation) }
        return wrapper
    }
}

// MARK: - AccountInfoSubscriptionAdapterHandler

extension EquilibriumTotalBalanceService: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        lock.lock()

        defer { lock.unlock() }

        switch result {
        case let .success(accountInfo):
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfos[key] = accountInfo
            if accountInfos.keys.count == equiliriubChainAsset.chain.chainAssets.count {
                calculateTotalBalance()
            }
        case let .failure(error):
            logger.error("\(error)")
        }
    }
}
