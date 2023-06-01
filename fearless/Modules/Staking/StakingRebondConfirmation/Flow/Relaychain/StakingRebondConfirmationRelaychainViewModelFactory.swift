import Foundation
import SoraFoundation
import SSFUtils

final class StakingRebondConfirmationRelaychainViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let iconGenerator: IconGenerating
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
        self.iconGenerator = iconGenerator
    }

    func createViewModel(viewModelState: StakingRebondConfirmationViewModelState) -> StakingRebondConfirmationViewModel? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationRelaychainViewModelState,
              let controllerItem = viewModelState.controller,
              let inputAmount = viewModelState.inputAmount else {
            return nil
        }

        let address = (try? AddressFactory.address(for: controllerItem.accountId, chain: chainAsset.chain)) ?? ""

        let formatter = formatterFactory.createInputFormatter(for: chainAsset.asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: inputAmount as NSNumber) ?? ""
        }

        let icon = try? iconGenerator.generateFromAddress(address)

        return StakingRebondConfirmationViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: controllerItem.name,
            amount: amount
        )
    }

    func createFeeViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationRelaychainViewModelState,
              let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
    }

    func createAssetBalanceViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationRelaychainViewModelState,
              let inputAmount = viewModelState.inputAmount,
              let unbonding = viewModelState.unbonding else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: unbonding,
            priceData: priceData
        )
    }
}
