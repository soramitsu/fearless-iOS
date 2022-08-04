import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

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
        guard let relaychainViewModelState = viewModelState as? StakingRedeemParachainViewModelState,
              let readyForRevokeDecimal = Decimal.fromSubstrateAmount(relaychainViewModelState.readyForRevoke, precision: Int16(asset.precision)) else {
            return nil
        }

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: readyForRevokeDecimal as NSNumber) ?? ""
        }

        let address = relaychainViewModelState.address ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        return StakingRedeemViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: relaychainViewModelState.wallet.fetch(for: relaychainViewModelState.chainAsset.chain.accountRequest())?.name,
            amount: amount
        )
    }

    func buildAssetViewModel(
        viewModelState: StakingRedeemViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let relaychainViewModelState = viewModelState as? StakingRedeemParachainViewModelState,
              let readyForRevokeDecimal = Decimal.fromSubstrateAmount(relaychainViewModelState.readyForRevoke, precision: Int16(asset.precision)) else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            readyForRevokeDecimal,
            balance: readyForRevokeDecimal,
            priceData: priceData
        )
    }
}
