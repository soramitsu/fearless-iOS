import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanListInteractor {
    weak var presenter: CrowdloanListInteractorOutputProtocol!

    let runtimeService: RuntimeCodingServiceProtocol
    let requestOperationFactory: StorageRequestFactoryProtocol
    let connection: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>
    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let chain: Chain
    let logger: LoggerProtocol?

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        requestOperationFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        chain: Chain,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeService = runtimeService
        self.requestOperationFactory = requestOperationFactory

        displayInfoProvider = singleValueProviderFactory.getJson(
            for: chain.crowdloanDisplayInfoURL()
        )

        self.singleValueProviderFactory = singleValueProviderFactory
        self.connection = connection
        self.operationManager = operationManager
        self.chain = chain
        self.logger = logger
    }

    private func provideCrowdloans() {
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

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let crowdloans = try mapOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveCrowdloans(result: .success(crowdloans))
                } catch {
                    if
                        let encodingError = error as? StorageKeyEncodingOperationError,
                        encodingError == .invalidStoragePath {
                        self?.presenter.didReceiveCrowdloans(result: .success([]))
                    } else {
                        self?.presenter.didReceiveCrowdloans(result: .failure(error))
                    }
                }
            }
        }

        let operations = [coderFactoryOperation, paraIdsOperation] + fundsOperation.allOperations + [mapOperation]

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func subscribeToDisplayInfo() {
        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveDisplayInfo(result: .failure(error))
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
}

extension CrowdloanListInteractor: CrowdloanListInteractorInputProtocol {
    func setup() {
        provideCrowdloans()

        subscribeToDisplayInfo()

        blockNumberProvider = subscribeToBlockNumber(for: chain, runtimeService: runtimeService)
    }

    func refresh() {
        displayInfoProvider.refresh()

        provideCrowdloans()
    }
}

extension CrowdloanListInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chain _: Chain) {
        presenter.didReceiveBlockNumber(result: result)
    }
}
