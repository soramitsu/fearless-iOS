import Foundation
import SoraFoundation
import FearlessUtils

final class StakingRedeemRelaychainViewModelFactory: StakingRedeemViewModelFactoryProtocol {
    let asset: AssetModel
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var formatterFactory = AssetBalanceFormatterFactory()
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(asset: AssetModel, balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.asset = asset
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func buildViewModel(viewModelState: StakingRedeemViewModelState) -> StakingRedeemViewModel? {
        guard let relaychainViewModelState = viewModelState as? StakingRedeemRelaychainViewModelState,
              let era = relaychainViewModelState.activeEra,
              let redeemable = relaychainViewModelState.stakingLedger?.redeemable(inEra: era),
              let redeemableDecimal = Decimal.fromSubstrateAmount(
                  redeemable,
                  precision: Int16(asset.precision)
              ) else {
            return nil
        }

        let formatter = formatterFactory.createInputFormatter(for: asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: redeemableDecimal as NSNumber) ?? ""
        }

        let address = relaychainViewModelState.controller?.toAddress() ?? ""
        let icon = try? iconGenerator.generateFromAddress(address)

        return StakingRedeemViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: relaychainViewModelState.controller?.name,
            amount: amount
        )
    }

    func buildAssetViewModel(
        viewModelState: StakingRedeemViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let relaychainViewModelState = viewModelState as? StakingRedeemRelaychainViewModelState,
              let era = relaychainViewModelState.activeEra,
              let redeemable = relaychainViewModelState.stakingLedger?.redeemable(inEra: era),
              let redeemableDecimal = Decimal.fromSubstrateAmount(
                  redeemable,
                  precision: Int16(asset.precision)
              ) else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            redeemableDecimal,
            balance: redeemableDecimal,
            priceData: priceData
        )
    }
}
