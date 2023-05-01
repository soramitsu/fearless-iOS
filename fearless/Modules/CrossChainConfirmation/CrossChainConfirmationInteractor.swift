import UIKit
import SSFXCM
import RobinHood
import BigInt
import SSFModels

protocol CrossChainConfirmationInteractorOutput: AnyObject {}

final class CrossChainConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainConfirmationInteractorOutput?

    private let teleportData: CrossChainConfirmationData
    private let xcmServices: XcmExtrinsicServices
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    init(
        teleportData: CrossChainConfirmationData,
        xcmServices: XcmExtrinsicServices,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.teleportData = teleportData
        self.xcmServices = xcmServices
        self.operationQueue = operationQueue
        self.logger = logger
    }

    // MARK: - Private methods

//    private func fetchRuntimeItems() {
//        let runtimeItemsOperation = runtimeItemRepository.fetchAllOperation(with: RepositoryFetchOptions())
//
//        runtimeItemsOperation.completionBlock = { [weak self] in
//            do {
//                let items = try runtimeItemsOperation.extractNoCancellableResultData()
//                self?.runtimeItems = items
//                self?.prepareDeps()
//            } catch {
//                self?.logger.error(error.localizedDescription)
//            }
//        }
//
//        operationQueue.addOperation(runtimeItemsOperation)
//    }

//    private func prepareDeps() {
//        do {
//            guard let originalRuntimeMetadataItem = runtimeItems.first(where: { $0.chain == teleportData.originalChainAsset.chain.chainId }),
//                  let destRuntimeMetadataItem = runtimeItems.first(where: { $0.chain == teleportData.destChainModel.chainId })
//            else {
//                throw ConvenienceError(error: "missing runtime item")
//            }
//
//            let deps = try depsContainer.prepareDepsFor(
//                originalChainAsset: teleportData.originalChainAsset,
//                destChainModel: teleportData.destChainModel,
//                originalRuntimeMetadataItem: originalRuntimeMetadataItem,
//                destRuntimeMetadataItem: destRuntimeMetadataItem
//            )
//            self.deps = deps
//        } catch {
//            logger.error(error.localizedDescription)
//        }
//    }
}

// MARK: - CrossChainConfirmationInteractorInput

extension CrossChainConfirmationInteractor: CrossChainConfirmationInteractorInput {
    func setup(with output: CrossChainConfirmationInteractorOutput) {
        self.output = output
    }

    func submit() {
        Task {
            let destChainRequest = teleportData.destChainModel.accountRequest()
            guard let destAccountId = teleportData.wallet.fetch(for: destChainRequest)?.accountId else {
                return
            }
            let result = await xcmServices.extrinsic.transfer(
                fromChainId: teleportData.originChainAsset.chain.chainId,
                assetSymbol: teleportData.originChainAsset.asset.symbol,
                destChainId: teleportData.destChainModel.chainId,
                destAccountId: destAccountId,
                amount: teleportData.amount
            )

            switch result {
            case let .success(hash):
                logger.verbose("submit hash \(hash)")
            case let .failure(error):
                logger.error("submit error \(error)")
            }
        }
    }
}
