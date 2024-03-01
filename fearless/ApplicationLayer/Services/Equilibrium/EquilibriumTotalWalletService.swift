import Foundation
import SSFUtils
import RobinHood
import BigInt
import SSFModels

protocol EquilibriumTotalBalanceServiceProtocol {
    var accountInfos: [ChainAssetKey: AccountInfo?] { get }
    var oraclePricesMap: [UInt64: BigUInt] { get }
    func fetchTotalBalance(completion: @escaping ((BigUInt) -> Void))
    func totalBalanceAfterTransfer(chainAsset: ChainAsset, amount: Decimal) -> Decimal?
}

final class EquilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol {
    // MARK: - Private properties

    private let wallet: MetaAccountModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let equilibriumChainAsset: ChainAsset
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol?
    private let engine: JSONRPCEngine?
    private let logger: LoggerProtocol

    private let lock = NSLock()

    var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    var oraclePricesMap: [UInt64: BigUInt] = [:]

    private var completion: ((BigUInt) -> Void)?
    private var equlibriumTotalBalance: BigUInt?

    // MARK: - Constructor

    init(
        wallet: MetaAccountModel,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        equilibriumChainAsset: ChainAsset,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol?,
        engine: JSONRPCEngine?,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.equilibriumChainAsset = equilibriumChainAsset
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.engine = engine
        self.logger = logger

        fetchOraclePrice()
        subscribeToAccountInfo()
    }

    // MARK: - Public methods

    func fetchTotalBalance(completion: @escaping ((BigUInt) -> Void)) {
        self.completion = completion
        fetchOraclePrice()
        subscribeToAccountInfo()
    }

    func totalBalanceAfterTransfer(chainAsset: ChainAsset, amount: Decimal) -> Decimal? {
        let request = equilibriumChainAsset.chain.accountRequest()
        guard oraclePricesMap.isNotEmpty,
              let accountId = wallet.fetch(for: request)?.accountId,
              let currencyId = UInt64(chainAsset.asset.currencyId.or("")),
              let equlibriumTotalBalance = equlibriumTotalBalance else {
            return nil
        }
        let precision = Int16(equilibriumChainAsset.asset.precision)
        let uniqueKey = chainAsset.uniqueKey(accountId: accountId)
        let price = oraclePricesMap[currencyId].or(.zero)

        let priceDecimal = Decimal
            .fromSubstrateAmount(price, precision: precision) ?? .zero
        let amountPrice = amount * priceDecimal
        let equlibriumTotalBalanceDecimal = Decimal
            .fromSubstrateAmount(equlibriumTotalBalance, precision: precision) ?? .zero

        return equlibriumTotalBalanceDecimal - amountPrice
    }

    // MARK: - Private methods

    private func calculateTotalBalance() {
        guard oraclePricesMap.isNotEmpty, accountInfos.isNotEmpty else {
            return
        }
        let request = equilibriumChainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return
        }
        let precision = Int16(equilibriumChainAsset.asset.precision)
        var equlibriumTotalBalance: BigUInt = .zero
        oraclePricesMap.forEach { key, price in
            guard let chainAsset = equilibriumChainAsset.chain.chainAssets.first(where: {
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
        self.equlibriumTotalBalance = equlibriumTotalBalance
        completion?(equlibriumTotalBalance)
    }

    private func subscribeToAccountInfo() {
        let request = equilibriumChainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return
        }
        accountInfoSubscriptionAdapter.subscribe(
            chainAsset: equilibriumChainAsset,
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
    ) -> AwaitOperation<[UInt64: BigUInt]> {
        let mapOraclePriceOperation = AwaitOperation<[UInt64: BigUInt]> { [weak self] in
            guard let strongSelf = self, let runtimeService = self?.runtimeService else {
                return [:]
            }
            let oraclePrice = try operation.targetOperation.extractNoCancellableResultData()
            let extractor = StorageKeyDataExtractor(runtimeService: runtimeService)

            let map = await oraclePrice.asyncReduce([UInt64: BigUInt]()) { partialResult, storageResponse -> [UInt64: BigUInt] in
                var map = partialResult
                guard let value = storageResponse.value else {
                    return map
                }

                do {
                    let currencyIdString: String = try await extractor.extractKey(
                        storageKey: storageResponse.key,
                        storagePath: .eqOraclePricePoint,
                        type: .u64
                    )
                    guard let currencyId = UInt64(currencyIdString) else {
                        return map
                    }

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
            if accountInfos.keys.count == equilibriumChainAsset.chain.chainAssets.count {
                calculateTotalBalance()
            }
        case let .failure(error):
            logger.error("\(error)")
        }
    }
}
