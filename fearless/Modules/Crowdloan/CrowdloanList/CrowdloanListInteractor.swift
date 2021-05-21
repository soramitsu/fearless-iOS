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
    let logger: LoggerProtocol?

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        requestOperationFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeService = runtimeService
        self.requestOperationFactory = requestOperationFactory
        self.displayInfoProvider = displayInfoProvider
        self.connection = connection
        self.operationManager = operationManager
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
                    self?.presenter.didReceiveCrowdloans(result: .failure(error))
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
        subscribeToDisplayInfo()
        provideCrowdloans()
    }

    func refresh() {
        displayInfoProvider.refresh()

        provideCrowdloans()
    }
}
