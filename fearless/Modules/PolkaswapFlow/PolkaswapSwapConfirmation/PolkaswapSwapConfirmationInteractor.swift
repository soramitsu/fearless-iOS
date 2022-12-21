import UIKit
import RobinHood
import BigInt

final class PolkaswapSwapConfirmationInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: PolkaswapSwapConfirmationInteractorOutput?

    private var params: PolkaswapPreviewParams
    private let signingWrapper: SigningWrapperProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private lazy var callFactory: SubstrateCallFactoryProtocol = {
        SubstrateCallFactory()
    }()

    init(
        params: PolkaswapPreviewParams,
        signingWrapper: SigningWrapperProtocol,
        extrinsicService: ExtrinsicServiceProtocol
    ) {
        self.params = params
        self.signingWrapper = signingWrapper
        self.extrinsicService = extrinsicService
    }

    private func builderClosure() -> ExtrinsicBuilderClosure? {
        let fromPrecision = Int16(params.swapFromChainAsset.asset.precision)

        guard let fromAssetId = params.swapFromChainAsset.asset.currencyId,
              let toAssetId = params.swapToChainAsset.asset.currencyId,
              let desired = params.fromAmount.toSubstrateAmount(precision: fromPrecision)
        else {
            return nil
        }

        let slip = BigUInt(integerLiteral: UInt64(params.slippadgeTolerance))
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
