import UIKit
import RobinHood
import SSFModels
import Web3

final class PolkaswapSwapConfirmationInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: PolkaswapSwapConfirmationInteractorOutput?

    private var params: PolkaswapPreviewParams
    private let signingWrapper: SigningWrapperProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private let callFactory: SubstrateCallFactoryProtocol

    init(
        params: PolkaswapPreviewParams,
        signingWrapper: SigningWrapperProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.params = params
        self.signingWrapper = signingWrapper
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
    }

    private func builderClosure() -> ExtrinsicBuilderClosure? {
        guard let fromAssetId = params.swapFromChainAsset.asset.currencyId,
              let toAssetId = params.swapToChainAsset.asset.currencyId
        else {
            return nil
        }

        let desired: BigUInt
        let slip: BigUInt
        let precisionFromAsset = Int16(params.swapFromChainAsset.asset.precision)
        let precisionToAsset = Int16(params.swapToChainAsset.asset.precision)
        switch params.swapVariant {
        case .desiredInput:
            desired = params.fromAmount.toSubstrateAmount(precision: precisionFromAsset) ?? .zero
            slip = params.minMaxValue.toSubstrateAmount(precision: precisionToAsset) ?? .zero
        case .desiredOutput:
            desired = params.toAmount.toSubstrateAmount(precision: precisionToAsset) ?? .zero
            slip = params.fromAmount.toSubstrateAmount(precision: precisionFromAsset) ?? .zero
        }

        let swapAmount = SwapAmount(
            type: params.swapVariant,
            desired: desired,
            slip: slip
        )
        let amountCall = [params.swapVariant: swapAmount]

        let swapCall = callFactory.swap(
            dexId: "\(params.polkaswapDexForRoute.code)",
            from: fromAssetId,
            to: toAssetId,
            amountCall: amountCall,
            type: params.market.code,
            filter: params.market.filterMode.rawValue
        )
        let builderClosure: ExtrinsicBuilderClosure = { builder in
            try builder.adding(call: swapCall)
        }

        return builderClosure
    }
}

// MARK: - PolkaswapSwapConfirmationInteractorInput

extension PolkaswapSwapConfirmationInteractor: PolkaswapSwapConfirmationInteractorInput {
    func setup(with output: PolkaswapSwapConfirmationInteractorOutput) {
        self.output = output
    }

    func update(params: PolkaswapPreviewParams) {
        self.params = params
    }

    func submit() {
        guard let builderClosure = builderClosure() else {
            return
        }

        extrinsicService.submit(
            builderClosure,
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.output?.didReceive(extrinsicResult: result)
        }
    }
}
