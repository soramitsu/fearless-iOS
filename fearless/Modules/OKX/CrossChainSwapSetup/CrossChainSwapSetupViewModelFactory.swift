import Foundation
import SSFModels
import BigInt

protocol CrossChainSwapSetupViewModelFactory: ErrorViewModelFactory {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel
    func buildSwapViewModel(
        swap: CrossChainSwap,
        sourceChainAsset: ChainAsset,
        targetChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        locale: Locale,
        selectedDexIds: [String]?,
        totalFiatFee: Decimal?,
        dexs: [OKXDexQuote]?,
        slippage: Decimal
    ) -> CrossChainSwapViewModel
    
    func buildFeeViewModel(
        originNetworkFee: Decimal?,
        sourceChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BalanceViewModelProtocol?
}

class CrossChainSwapSetupViewModelFactoryImpl: CrossChainSwapSetupViewModelFactory {
    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel
        )
    }

    func buildSwapViewModel(
        swap: CrossChainSwap,
        sourceChainAsset: ChainAsset,
        targetChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        locale: Locale,
        selectedDexIds: [String]?,
        totalFiatFee: Decimal?,
        dexs: [OKXDexQuote]?,
        slippage: Decimal
    ) -> CrossChainSwapViewModel {
        let isCrossChain = sourceChainAsset.chain.chainId != targetChainAsset.chain.chainId
        
        let utilityFeeChainAsset = sourceChainAsset.chain.utilityChainAssets().first ?? sourceChainAsset
        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceChainAsset)
        let targetBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: targetChainAsset)

        let minimumReceiveAmount = swap.toAmount.flatMap { BigUInt(string: $0) }
        let minimumReceiveAmountDecimal = minimumReceiveAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetChainAsset.asset.precision)) }
        let minimumReceiveAmountViewModel = minimumReceiveAmountDecimal.flatMap {
            targetBalanceViewModelFactory?.balanceFromPrice(
                $0,
                priceData: targetChainAsset.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }

        let receiveAmount = swap.toAmount.flatMap { BigUInt(string: $0) }
        let receiveAmountDecimal = receiveAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(targetChainAsset.asset.precision)) }

        let sendAmount = swap.fromAmount.flatMap { BigUInt(string: $0) }
        let sendAmountDecimal = sendAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(sourceChainAsset.asset.precision)) }

        let sendTokenRatio: Decimal? = receiveAmountDecimal.flatMap {
            guard let sendAmountDecimal else {
                return nil
            }
            return $0 / sendAmountDecimal
        }

        let receiveTokenRatio: Decimal? = sendAmountDecimal.flatMap {
            guard let receiveAmountDecimal else {
                return nil
            }
            return $0 / receiveAmountDecimal
        }

        let sendTokenRatioString = sendTokenRatio.flatMap { $0.string(maximumFractionDigits: 5) }
        let receiveTokenRatioString = receiveTokenRatio.flatMap { $0.string(maximumFractionDigits: 5) }

        let totalFiatFeeString = totalFiatFee.flatMap { $0.string(maximumFractionDigits: 8) }

        let sendTokenRatioTitle = "\(sourceChainAsset.asset.symbol.uppercased())/\(targetChainAsset.asset.symbol.uppercased())"
        let receiveTokenRatioTitle = "\(targetChainAsset.asset.symbol.uppercased())/\(sourceChainAsset.asset.symbol.uppercased())"
        let liquiditySources: String? = (dexs?.count).map { count in
            let selectedCount = selectedDexIds?.count ?? count
            return "\(selectedCount)/\(count)"
        }
        let txCommission = totalFiatFeeString.flatMap { "\(wallet.selectedCurrency.symbol) \($0)" }
        
        let slippageTitle = (slippage * 100).description + "%"
        let slippageViewModel = TitleMultiValueViewModel(title: slippageTitle, subtitle: nil, detailsButtonVisible: true)
        
        let sourceChainIconViewModel = sourceChainAsset.chain.icon.flatMap { RemoteImageViewModel(url: $0)}
        let targetChainIconViewModel = targetChainAsset.chain.icon.flatMap { RemoteImageViewModel(url: $0)}
        
        var fromRouteViewModels = swap.fromRoute?.compactMap {
            ImageMarkedLabelViewModel(labelText: $0, imageViewModel: sourceChainIconViewModel)
        }
        var toRouteViewModels = swap.toRoute?.compactMap {
            ImageMarkedLabelViewModel(labelText: $0, imageViewModel: targetChainIconViewModel)
        }
        
        if isCrossChain && (fromRouteViewModels).isNullOrEmpty {
            let sourceTokenViewModel = ImageMarkedLabelViewModel(labelText: sourceChainAsset.asset.symbol.uppercased(), imageViewModel: sourceChainIconViewModel)
            fromRouteViewModels?.insert(sourceTokenViewModel, at: 0)
        }
        
        if isCrossChain && (toRouteViewModels).isNullOrEmpty {
            let targetTokenViewModel = ImageMarkedLabelViewModel(labelText: targetChainAsset.asset.symbol.uppercased(), imageViewModel: targetChainIconViewModel)
            toRouteViewModels?.insert(targetTokenViewModel, at: 0)
        }
        
        let routeViewModels: [ImageMarkedLabelViewModel] = [fromRouteViewModels, toRouteViewModels].compactMap { $0 }.reduce([], +)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        let txTime = (swap.estimatedTime)
            .flatMap { TimeInterval($0) }
            .flatMap { formatter.string(from: TimeInterval($0)) }
        let routeViewModel = TitleMultiValueViewModel(title: swap.dexName?.capitalized, subtitle: nil, detailsButtonVisible: true)
        let walletFee = swap.fromAmount.flatMap { BigUInt(string: $0) }.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(sourceChainAsset.asset.precision))}.or(.zero) * Decimal(string: CrossChain.Constants.walletFeePercent).or(.zero)/100
        let walletFeeViewModel = sourceBalanceViewModelFactory?.balanceFromPrice(walletFee, priceData: sourceChainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto)
        
        return CrossChainSwapViewModel(
            minimumReceived: minimumReceiveAmountViewModel?.value(for: locale),
            route: routeViewModel,
            sendTokenRatio: sendTokenRatioString,
            receiveTokenRatio: receiveTokenRatioString,
            fee: txCommission,
            sendTokenRatioTitle: sendTokenRatioTitle,
            receiveTokenRatioTitle: receiveTokenRatioTitle,
            liquiditySources: liquiditySources,
            slippageTitle: slippageViewModel,
            routeViewModels: routeViewModels,
            txTime: txTime,
            walletFee: walletFeeViewModel?.value(for: locale)
        )
    }
    
    func buildFeeViewModel(
        originNetworkFee: Decimal?,
        sourceChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        let utilityFeeChainAsset = sourceChainAsset.chain.utilityChainAssets().first ?? sourceChainAsset

        let feeBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityFeeChainAsset)
        
        let originNetworkFeeViewModel = originNetworkFee.flatMap {
            feeBalanceViewModelFactory?.balanceFromPrice(
                $0,
                priceData: utilityFeeChainAsset.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }
        
        return originNetworkFeeViewModel?.value(for: locale)
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
        return balanceViewModelFactory
    }
}
