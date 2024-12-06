import Foundation
import SSFModels
import BigInt

protocol CrossChainSwapConfirmViewModelFactory: CrossChainSwapSetupViewModelFactory {
    func buildSwapAmountInfoViewModel(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        swap: CrossChainSwap,
        locale: Locale
    ) -> SwapAmountInfoViewModel

    func buildDoubleImageViewModel(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset
    ) -> PolkaswapDoubleSymbolViewModel

    func buildFeeViewModel(
        utilityChainAsset: ChainAsset,
        fee: BigUInt,
        locale: Locale
    ) -> BalanceViewModelProtocol?
}

final class CrossChainSwapConfirmViewModelFactoryImpl: CrossChainSwapSetupViewModelFactoryImpl, CrossChainSwapConfirmViewModelFactory {
    private let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func buildFeeViewModel(utilityChainAsset: ChainAsset, fee: BigUInt, locale: Locale) -> BalanceViewModelProtocol? {
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityChainAsset)
        guard let feeDecimal = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityChainAsset.asset.precision)) else {
            return nil
        }

        return balanceViewModelFactory?.balanceFromPrice(feeDecimal, priceData: utilityChainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto).value(for: locale)
    }

    func buildDoubleImageViewModel(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset
    ) -> PolkaswapDoubleSymbolViewModel {
        let leftColor = HexColorConverter.hexStringToUIColor(hex: swapFromChainAsset.asset.color)?.cgColor
        let rightColor = HexColorConverter.hexStringToUIColor(hex: swapToChainAsset.asset.color)?.cgColor
        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: swapFromChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            rightViewModel: swapToChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            leftShadowColor: leftColor,
            rightShadowColor: rightColor
        )

        return doubleImageViewViewModel
    }

    func buildSwapAmountInfoViewModel(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        swap: CrossChainSwap,
        locale: Locale
    ) -> SwapAmountInfoViewModel {
        let swapFromViewModel = buildFromSwapDirectionViewModel(
            chainAsset: swapFromChainAsset,
            swap: swap,
            locale: locale
        )
        let swapToViewModel = buildToSwapDirectionViewModel(
            chainAsset: swapToChainAsset,
            swap: swap,
            locale: locale
        )

        return SwapAmountInfoViewModel(
            swapFromViewModel: swapFromViewModel,
            swapToViewModel: swapToViewModel
        )
    }

    private func buildFromSwapDirectionViewModel(
        chainAsset: ChainAsset,
        swap: CrossChainSwap,
        locale: Locale
    ) -> SwapDirectionViewModel {
        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)

        let amount = swap.fromAmount.flatMap {
            BigUInt(string: $0)
        }

        let amountDecimal = amount.flatMap {
            Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
        }

        let amountViewModel = amountDecimal.flatMap {
            sourceBalanceViewModelFactory?.balanceFromPrice(
                $0,
                priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }

        let chainViewModel = UniqueChainViewModel(
            text: chainAsset.chain.name,
            icon: RemoteImageViewModel(url: chainAsset.chain.icon)
        )

        return SwapDirectionViewModel(
            balanceViewModel: amountViewModel?.value(for: locale),
            chainViewModel: chainViewModel
        )
    }

    private func buildToSwapDirectionViewModel(
        chainAsset: ChainAsset,
        swap: CrossChainSwap,
        locale: Locale
    ) -> SwapDirectionViewModel {
        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)

        let amount = swap.toAmount.flatMap {
            BigUInt(string: $0)
        }

        let amountDecimal = amount.flatMap {
            Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision))
        }

        let amountViewModel = amountDecimal.flatMap {
            sourceBalanceViewModelFactory?.balanceFromPrice(
                $0,
                priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }

        let chainViewModel = UniqueChainViewModel(
            text: chainAsset.chain.name,
            icon: RemoteImageViewModel(url: chainAsset.chain.icon)
        )

        return SwapDirectionViewModel(
            balanceViewModel: amountViewModel?.value(for: locale),
            chainViewModel: chainViewModel
        )
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
