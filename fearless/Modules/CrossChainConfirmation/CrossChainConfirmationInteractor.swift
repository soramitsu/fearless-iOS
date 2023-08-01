import UIKit
import SSFXCM
import RobinHood
import BigInt
import SSFModels

protocol CrossChainConfirmationInteractorOutput: AnyObject {
    func didTransfer(result: Result<String, Error>)
}

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
}

// MARK: - CrossChainConfirmationInteractorInput

extension CrossChainConfirmationInteractor: CrossChainConfirmationInteractorInput {
    func setup(with output: CrossChainConfirmationInteractorOutput) {
        self.output = output
    }

    func submit() {
        Task {
            let address = teleportData.recipientAddress
            let chain = teleportData.destChainModel
            let precision = Int16(teleportData.originChainAsset.asset.precision)
            guard
                let destAccountId = try? AddressFactory.accountId(from: address, chain: chain),
                let destFeeValue = teleportData.destChainFeeDecimal.toSubstrateAmount(precision: precision)
            else {
                return
            }

            let amount = teleportData.amount + destFeeValue
            let result = await xcmServices.extrinsic.transfer(
                fromChainId: teleportData.originChainAsset.chain.chainId,
                assetSymbol: teleportData.originChainAsset.asset.symbol,
                destChainId: teleportData.destChainModel.chainId,
                destAccountId: destAccountId,
                amount: amount
            )

            await MainActor.run {
                self.output?.didTransfer(result: result)
            }
        }
    }
}
