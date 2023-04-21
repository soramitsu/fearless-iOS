import Foundation
import SoraFoundation
import FearlessUtils

final class StakingRebondConfirmationParachainViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let iconGenerator: IconGenerating
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.iconGenerator = iconGenerator
    }

    func createViewModel(viewModelState: StakingRebondConfirmationViewModelState) -> StakingRebondConfirmationViewModel? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationParachainViewModelState,
              let account = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let address = (try? AddressFactory.address(for: account.accountId, chain: chainAsset.chain)) ?? ""

        let formatter = formatterFactory.createInputFormatter(for: chainAsset.asset.displayInfo)

        let amount = LocalizableResource { locale in
            formatter.value(for: locale).string(from: viewModelState.inputAmount as NSNumber) ?? ""
        }

        let icon = try? iconGenerator.generateFromAddress(address)

        return StakingRebondConfirmationViewModel(
            senderAddress: address,
            senderIcon: icon,
            senderName: account.name,
            amount: amount
        )
    }

    func createFeeViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationParachainViewModelState,
              let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
    }

    func createAssetBalanceViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? StakingRebondConfirmationParachainViewModelState else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.inputAmount,
            balance: viewModelState.inputAmount,
            priceData: priceData
        )
    }
}
