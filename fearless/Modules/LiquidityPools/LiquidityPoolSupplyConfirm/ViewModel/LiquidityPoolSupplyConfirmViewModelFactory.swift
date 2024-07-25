import Foundation
import SSFPools
import SSFModels
import UIKit

protocol LiquidityPoolSupplyConfirmViewModelFactory: LiquidityPoolSupplyViewModelFactory {
    func buildViewModel(
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        locale: Locale
    ) -> LiquidityPoolSupplyConfirmViewModel?
}

final class LiquidityPoolSupplyConfirmViewModelFactoryDefault: LiquidityPoolSupplyViewModelFactoryDefault, LiquidityPoolSupplyConfirmViewModelFactory {
    private enum Constants {
        static let imageWidth: CGFloat = 8
        static let imageHeight: CGFloat = 14
        static let imageVerticalPosition: CGFloat = 6
    }

    func buildViewModel(
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        liquidityPair: LiquidityPair,
        chain: ChainModel,
        locale: Locale
    ) -> LiquidityPoolSupplyConfirmViewModel? {
        guard
            let baseChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.baseAssetId }),
            let targetChainAsset = chain.chainAssets.first(where: { $0.asset.currencyId == liquidityPair.targetAssetId })
        else {
            return nil
        }

        let leftColor = HexColorConverter.hexStringToUIColor(hex: baseChainAsset.asset.color)?.cgColor
        let rightColor = HexColorConverter.hexStringToUIColor(hex: targetChainAsset.asset.color)?.cgColor
        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: baseChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            rightViewModel: targetChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            leftShadowColor: leftColor,
            rightShadowColor: rightColor
        )

        let amountsText = buildAmountsText(baseAssetAmount: baseAssetAmount, targetAssetAmount: targetAssetAmount, baseChainAsset: baseChainAsset, targetChainAsset: targetChainAsset, locale: locale)

        return LiquidityPoolSupplyConfirmViewModel(
            amountsText: amountsText,
            doubleImageViewViewModel: doubleImageViewViewModel
        )
    }

    private func buildAmountsText(
        baseAssetAmount: Decimal,
        targetAssetAmount: Decimal,
        baseChainAsset: ChainAsset,
        targetChainAsset: ChainAsset,
        locale: Locale
    ) -> NSMutableAttributedString {
        let fromAmount = baseAssetAmount.toString(locale: locale)
        let fromName = baseChainAsset.asset.symbolUppercased
        let leftText = [fromAmount, fromName]
            .compactMap { $0 }
            .joined(separator: " ")

        let rightAmount = targetAssetAmount.toString(locale: locale)
        let rightName = targetChainAsset.asset.symbolUppercased
        let rightText = [rightAmount, rightName]
            .compactMap { $0 }
            .joined(separator: " ")

        let amountsTitle = insertArrow(in: [leftText, rightText])
        return amountsTitle
    }

    private func insertArrow(in texts: [String]) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        texts.enumerated().forEach { index, text in
            attributedString.append(NSAttributedString(string: text))
            if index % 2 == 0 {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = R.image.iconSmallArrow()
                imageAttachment.bounds = CGRect(
                    x: 0,
                    y: -Constants.imageVerticalPosition,
                    width: imageAttachment.image?.size.width ?? Constants.imageWidth,
                    height: imageAttachment.image?.size.height ?? Constants.imageHeight
                )

                let imageString = NSAttributedString(attachment: imageAttachment)
                attributedString.append(imageString)
                attributedString.append(NSAttributedString(string: "  "))
            }
        }

        return attributedString
    }
}
