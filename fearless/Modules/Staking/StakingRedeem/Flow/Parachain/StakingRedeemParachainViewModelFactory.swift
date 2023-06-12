import Foundation
import SoraFoundation
import SSFUtils
import SSFModels
import Web3

final class StakingRedeemParachainViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    private let asset: AssetModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private var iconGenerator: IconGenerating
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        asset: AssetModel,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    func buildViewModel(viewModelState: StakingRedeemViewModelState) -> StakingRedeemViewModel? {
        guard let parachainViewModelState = viewModelState as? StakingRedeemParachainViewModelState,
              let readyForRevokeDecimal = Decimal.fromSubstrateAmount(parachainViewModelState.readyForRevoke, precision: Int16(asset.precision)) else {
            return nil
        }

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: readyForRevokeDecimal as NSNumber) ?? ""
        }

        let address = parachainViewModelState.address ?? ""
        let senderIcon = try? iconGenerator.generateFromAddress(address)
        let title = LocalizableResource { locale in
            R.string.localizable.stakingRevokeTokens(preferredLanguages: locale.rLanguages)
        }
        let collatorIcon = try? iconGenerator.generateFromAddress(parachainViewModelState.collator.address)

        return StakingRedeemViewModel(
            senderAddress: address,
            senderIcon: senderIcon,
            senderName: parachainViewModelState.wallet.fetch(for: parachainViewModelState.chainAsset.chain.accountRequest())?.name,
            amount: amount,
            title: title,
            collatorName: parachainViewModelState.collator.identity?.name,
            collatorIcon: collatorIcon
        )
    }

    func buildAssetViewModel(
        viewModelState: StakingRedeemViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let relaychainViewModelState = viewModelState as? StakingRedeemParachainViewModelState,
              let readyForRevokeDecimal = Decimal.fromSubstrateAmount(
                  relaychainViewModelState.readyForRevoke,
                  precision: Int16(asset.precision)
              ) else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            readyForRevokeDecimal,
            balance: readyForRevokeDecimal,
            priceData: priceData
        )
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingStakeLessHint(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconInfoFilled()?.tinted(with: R.color.colorStrokeGray()!)
                )
            )

            return items
        }
    }
}
