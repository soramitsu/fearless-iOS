import SSFUtils
import SSFModels
import Foundation

protocol SendViewModelFactoryProtocol {
    func buildRecipientViewModel(
        address: String,
        isValid: Bool?,
        canEditing: Bool
    ) -> RecipientViewModel
    func buildNetworkViewModel(
        chain: ChainModel
    ) -> SelectNetworkViewModel
    func createAssetBalanceViewModel(
        inputAmount: Decimal?,
        availableBalance: Decimal?,
        chainAsset: ChainAsset,
        canSelectAsset: Bool,
        locale: Locale
    ) -> AssetBalanceViewModelProtocol
    func createBalanceInputViewModel(
        inputAmount: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> IAmountInputViewModel
    func balanceFromPrice(
        chainAsset: ChainAsset,
        balance: Decimal,
        locale: Locale
    ) -> BalanceViewModelProtocol
}

final class SendViewModelFactory: SendViewModelFactoryProtocol {
    private let wallet: MetaAccountModel
    private let iconGenerator: IconGenerating

    init(
        wallet: MetaAccountModel,
        iconGenerator: IconGenerating
    ) {
        self.wallet = wallet
        self.iconGenerator = iconGenerator
    }

    func buildRecipientViewModel(
        address: String,
        isValid: Bool?,
        canEditing: Bool
    ) -> RecipientViewModel {
        RecipientViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            isValid: isValid,
            canEditing: canEditing
        )
    }

    func buildNetworkViewModel(chain: ChainModel) -> SelectNetworkViewModel {
        let iconViewModel = chain.icon.map { RemoteImageViewModel(url: $0) }
        return SelectNetworkViewModel(
            chainName: chain.name,
            iconViewModel: iconViewModel,
            canEdit: false
        )
    }

    func createAssetBalanceViewModel(
        inputAmount: Decimal?,
        availableBalance: Decimal?,
        chainAsset: ChainAsset,
        canSelectAsset: Bool,
        locale: Locale
    ) -> AssetBalanceViewModelProtocol {
        let balanceViewModelFactory = buildBalanceViewModelFactory(for: chainAsset)
        let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency)
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: availableBalance,
            priceData: priceData,
            selectable: canSelectAsset
        ).value(for: locale)
        return viewModel
    }

    func createBalanceInputViewModel(
        inputAmount: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> IAmountInputViewModel {
        let balanceViewModelFactory = buildBalanceViewModelFactory(for: chainAsset)
        let viewModel = balanceViewModelFactory
            .createBalanceInputViewModel(inputAmount)
            .value(for: locale)
        return viewModel
    }

    func balanceFromPrice(
        chainAsset: ChainAsset,
        balance: Decimal,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let balanceViewModelFactory = buildBalanceViewModelFactory(for: chainAsset)
        let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency)
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balance,
            priceData: priceData,
            usageCase: .detailsCrypto
        ).value(for: locale)
        return viewModel
    }

    // MARK: - Private methods

    private func buildBalanceViewModelFactory(
        for chainAsset: ChainAsset
    ) -> BalanceViewModelFactoryProtocol {
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        return balanceViewModelFactory
    }
}
