import SSFModels
import Foundation
import BigInt

class CrossChainSwapBasePresenter<T> where T: CrossChainBaseInteractorInput {
    let wallet: MetaAccountModel
    let interactor: T
    
    var originNetworkFee: Decimal?
    var totalFiatFee: Decimal?

    init(
        wallet: MetaAccountModel,
        interactor: T
    ) {
        self.wallet = wallet
        self.interactor = interactor
    }
    
    func estimateFee(for quote: CrossChainSwap, chainAsset: ChainAsset) async throws -> Decimal? {
        let fee = try await interactor.estimateFee(for: quote, chainAsset: chainAsset)
        return fee.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) }
    }
    
    func calculateTotalFiatFee(
        for swap: CrossChainSwap?,
        swapFromChainAsset: ChainAsset?,
        originNetworkFee: Decimal?
    ) async throws -> Decimal? {
        guard let swap,
              let swapFromChainAsset,
              let originNetworkFee
        else {
            return nil
        }
        
        let okxChainAssets = try await interactor.fetchChainAssets(for: swapFromChainAsset.chain)

        let sourceChainFeeNativeToken = swapFromChainAsset.chain.utilityChainAssets().first
        let crossChainFeeToken = okxChainAssets.first(where: { $0.asset.id.lowercased() == swap.contractAddress?.lowercased() })

        let sourceChainFiatFee: Decimal? = sourceChainFeeNativeToken.flatMap {
            guard
                let price = $0.asset.getPrice(for: wallet.selectedCurrency),
                let priceDecimal = Decimal(string: price.price)
            else {
                return nil
            }
            return originNetworkFee * priceDecimal
        }

        let crossChainFee: Decimal? = swap.crossChainFee.flatMap { Decimal(string: $0) }

        let crossChainFiatFee: Decimal? = crossChainFee.flatMap { fee in
            guard let crossChainFee,
                  let crossChainFeeToken,
                  let price = crossChainFeeToken.asset.getPrice(for: wallet.selectedCurrency),
                  let priceDecimal = Decimal(string: price.price)
            else {
                return nil
            }

            return crossChainFee * priceDecimal
        }

        let fiatFee = swap.fiatFee.flatMap { Decimal(string: $0) }

        let totalFiatFee = [
            crossChainFiatFee,
            sourceChainFiatFee,
            fiatFee
        ].compactMap { $0 }.reduce(0, +)

        return totalFiatFee
        
    }
}
