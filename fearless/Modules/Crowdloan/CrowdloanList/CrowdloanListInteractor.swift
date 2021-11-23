import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var output: CrowdloanListInteractorOutputProtocol?

    let selectedAddress: AccountAddress
    let runtimeService: RuntimeCodingServiceProtocol
    let crowdloanOperationFactory: CrowdloanOperationFactoryProtocol
    let connection: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let walletAssetId: WalletAssetId?
    private var failedAddMemoExtrinsics: [ParaId: [CrowdloanAddMemoParam]] = [:]
    private var failedMemoRequestsAttemptsCount: Int = 0

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var crowdloansRequest: CompoundOperationWrapper<[Crowdloan]>?

    init(
        selectedAddress: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol,
        crowdloanOperationFactory: CrowdloanOperationFactoryProtocol,
        connection: JSONRPCEngine,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        chain: Chain,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        walletAssetId: WalletAssetId?
    ) {
        self.selectedAddress = selectedAddress
        self.runtimeService = runtimeService
        self.crowdloanOperationFactory = crowdloanOperationFactory

        displayInfoProvider = singleValueProviderFactory.getJson(
            for: chain.crowdloanDisplayInfoURL()
        )

        self.singleValueProviderFactory = singleValueProviderFactory
        self.connection = connection
        self.operationManager = operationManager
        self.chain = chain
        self.logger = logger
        self.subscanOperationFactory = subscanOperationFactory
        self.walletAssetId = walletAssetId
    }

    private func handleFinalizedMemos(_ finalized: [SubscanMemoItemData]) {
        let memos: [(Bool, [CrowdloanAddMemoParam])] = finalized.compactMap {
            guard let success = $0.success, let paramsData = $0.params.data(using: .utf8) else {
                output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
                return nil
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let params = try decoder.decode([CrowdloanAddMemoParam].self, from: paramsData)
                return (success, params)
            } catch {
                output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
                assertionFailure(error.localizedDescription)
                return nil
            }
        }

        var memoByParaIds: [ParaId: [(success: Bool, memo: String)]] = [:]

        for (success, params) in memos {
            var paraId: ParaId?
            var memoValue: String?
            for param in params {
                switch param {
                case let .index(index): paraId = index.value
                case let .memo(memo): memoValue = memo.value
                }
            }

            if let paraId = paraId, let memo = memoValue {
                if memoByParaIds[paraId] == nil {
                    memoByParaIds[paraId] = []
                }

                memoByParaIds[paraId]?.append((success, memo))
            }
        }

        var failedMemos: [ParaId: String] = [:]

        for (paraId, memos) in memoByParaIds {
            let successful = memos.first { $0.success } != nil

            if successful {
                continue
            }

            guard let failed = memos.last(where: { !$0.success })?.memo else {
                continue
            }

            do {
                failedMemos[paraId] = try Data(hexString: failed).toHex(includePrefix: true)
            } catch {
                output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
                assertionFailure(error.localizedDescription)
            }
        }

        output?.didReceiveFailedMemos(result: .success(failedMemos))
    }

    func requestMemoHistory() {
        failedMemoRequestsAttemptsCount += 1
        let call = CallCodingPath.addMemo

        guard let subscanUrl = walletAssetId?.subscanUrl else {
            output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
            logger?.error("Failed to load call history: \(call)")
            return
        }

        let extrinsicsURL = subscanUrl.appendingPathComponent(SubscanApi.extrinsics)

        let historyInfo = HistoryInfo(
            address: selectedAddress,
            row: 100,
            page: 0
        )

        let fetchOperation = subscanOperationFactory.fetchAllExtrinsicForCall(
            extrinsicsURL,
            call: call,
            historyInfo: historyInfo,
            of: SubscanMemoData.self
        )

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let self = `self` else {
                    return
                }

                do {
                    let response = try fetchOperation.extractNoCancellableResultData()

                    guard let finalized = response.extrinsics?.filter { $0.finalized == true }, !finalized.isEmpty else {
                        self.output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
                        return
                    }

                    self.handleFinalizedMemos(finalized)
                } catch {
                    self.output?.didReceiveFailedMemos(result: .failure(CommonError.internal))
                    self.logger?.error("Failed to load call history: \(call)")

                    if self.failedMemoRequestsAttemptsCount <= 3 {
                        self.requestMemoHistory()
                    }
                }
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    private func provideContributions(for crowdloans: [Crowdloan]) {
        guard !crowdloans.isEmpty else {
            output?.didReceiveContributions(result: .success([:]))
            return
        }

        let contributionsOperation: BaseOperation<[CrowdloanContributionResponse]> =
            OperationCombiningService(operationManager: operationManager) { [weak self] in
                guard let strongSelf = self else {
                    return []
                }

                return crowdloans.map { crowdloan in
                    strongSelf.crowdloanOperationFactory.fetchContributionOperation(
                        connection: strongSelf.connection,
                        runtimeService: strongSelf.runtimeService,
                        address: strongSelf.selectedAddress,
                        trieIndex: crowdloan.fundInfo.trieIndex
                    )
                }
            }.longrunOperation()

        contributionsOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let contributions = try contributionsOperation.extractNoCancellableResultData().toDict()
                    self?.output?.didReceiveContributions(result: .success(contributions))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.output?.didReceiveContributions(result: .success([:]))
                    } else {
                        self?.output?.didReceiveContributions(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: [contributionsOperation], in: .transient)
    }

    private func provideLeaseInfo(for crowdloans: [Crowdloan]) {
        guard !crowdloans.isEmpty else {
            output?.didReceiveLeaseInfo(result: .success([:]))
            return
        }

        let paraIds = crowdloans.map(\.paraId)

        let queryWrapper = crowdloanOperationFactory.fetchLeaseInfoOperation(
            connection: connection,
            runtimeService: runtimeService,
            paraIds: paraIds
        )

        queryWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let leaseInfo = try queryWrapper.targetOperation.extractNoCancellableResultData().toMap()
                    self?.output?.didReceiveLeaseInfo(result: .success(leaseInfo))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.output?.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.output?.didReceiveLeaseInfo(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: queryWrapper.allOperations, in: .transient)
    }

    private func provideCrowdloans() {
        guard crowdloansRequest == nil else {
            return
        }

        let crowdloanWrapper = crowdloanOperationFactory.fetchCrowdloansOperation(
            connection: connection,
            runtimeService: runtimeService,
            chain: chain
        )

        crowdloansRequest = crowdloanWrapper

        crowdloanWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.crowdloansRequest = nil

                do {
                    let crowdloans = try crowdloanWrapper.targetOperation.extractNoCancellableResultData()
                    self?.provideContributions(for: crowdloans)
                    self?.provideLeaseInfo(for: crowdloans)
                    self?.output?.didReceiveCrowdloans(result: .success(crowdloans))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.output?.didReceiveCrowdloans(result: .success([]))
                        self?.output?.didReceiveContributions(result: .success([:]))
                        self?.output?.didReceiveLeaseInfo(result: .success([:]))
                    } else {
                        self?.output?.didReceiveCrowdloans(result: .failure(error))
                        self?.output?.didReceiveContributions(result: .failure(error))
                        self?.output?.didReceiveLeaseInfo(result: .failure(error))
                    }
                }
            }
        }

        operationManager.enqueue(operations: crowdloanWrapper.allOperations, in: .transient)
    }

    private func subscribeToDisplayInfo() {
        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.output?.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.output?.didReceiveDisplayInfo(result: .failure(error))
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func provideConstants() {
        fetchConstant(
            for: .babeBlockTime,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BlockTime, Error>) in
            self?.output?.didReceiveBlockDuration(result: result)
        }

        fetchConstant(
            for: .paraLeasingPeriod,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<LeasingPeriod, Error>) in
            self?.output?.didReceiveLeasingPeriod(result: result)
        }
    }
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        requestMemoHistory()

        provideCrowdloans()

        subscribeToDisplayInfo()

        provideConstants()
    }

    func refresh() {
        requestMemoHistory()

        displayInfoProvider.refresh()

        provideCrowdloans()

        provideConstants()
    }

    func becomeOnline() {
        guard blockNumberProvider == nil else {
            return
        }

        blockNumberProvider = subscribeToBlockNumber(for: chain, runtimeService: runtimeService)
    }

    func putOffline() {
        clear(dataProvider: &blockNumberProvider)
    }
}

extension CrowdloanListInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chain _: Chain) {
        provideCrowdloans()
        output?.didReceiveBlockNumber(result: result)
    }
}
