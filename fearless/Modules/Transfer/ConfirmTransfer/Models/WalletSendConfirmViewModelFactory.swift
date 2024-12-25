import Foundation
import SSFModels
import SSFCrypto

struct WalletSendConfirmViewModelFactoryParameters {
    let amount: Decimal
    let senderAccountViewModel: AccountViewModel?
    let receiverAccountViewModel: AccountViewModel?
    let assetBalanceViewModel: AssetBalanceViewModelProtocol?
    let tipRequired: Bool
    let tipViewModel: BalanceViewModelProtocol?
    let feeViewModel: BalanceViewModelProtocol?
    let wallet: MetaAccountModel
    let locale: Locale
    let scamInfo: ScamInfo?
    let assetModel: AssetModel
}

protocol WalletSendConfirmViewModelFactoryProtocol {
    func buildViewModel(
        useCase: TransferFlowUseCase,
        scamInfo: ScamInfo?,
        locale: Locale
    ) throws -> WalletSendConfirmViewModel
}

final class WalletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol {
    private let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let assetInfo: AssetBalanceDisplayInfo
    private let wallet: MetaAccountModel

    init(
        wallet: MetaAccountModel,
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo
    ) {
        self.wallet = wallet
        self.amountFormatterFactory = amountFormatterFactory
        self.assetInfo = assetInfo
    }

    func buildViewModel(
        useCase: TransferFlowUseCase,
        scamInfo: ScamInfo?,
        locale: Locale
    ) throws -> WalletSendConfirmViewModel {
        let formatter = amountFormatterFactory.createTokenFormatter(for: assetInfo, usageCase: .detailsCrypto)
        guard
            let amount = useCase.amount(),
            let selectedChainAsset = useCase.selectedChainAsset,
            let utilityChainAsset = useCase.utilityChainAsset,
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: selectedChainAsset),
            let utilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityChainAsset),
            let accountId = wallet.fetch(for: selectedChainAsset.chain.accountRequest())?.accountId,
            let senderAddress = try? AddressFactory.address(for: accountId, chain: selectedChainAsset.chain),
            let receiverAddressString = useCase.recipientAddress
        else {
            throw ConvenienceError(error: "Missing requared params")
        }

        let inputAmount = formatter.value(for: locale).stringFromDecimal(amount) ?? ""
        let amountString = R.string.localizable.sendConfirmAmountTitle(
            inputAmount,
            preferredLanguages: locale.rLanguages
        )
        let amountAttributedString = NSMutableAttributedString(string: amountString)
        amountAttributedString.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorWhite()!.cgColor,
            range: (amountString as NSString).range(of: inputAmount)
        )

        let shadowColor = HexColorConverter.hexStringToUIColor(
            hex: selectedChainAsset.asset.color
        )?.cgColor
        let iconViewModel = selectedChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) }
        let symbolViewModel = SymbolViewModel(
            iconViewModel: iconViewModel,
            shadowColor: shadowColor
        )

        let priceString = buildPriceString(
            useCase: useCase,
            locale: locale,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let feeViewModel = buildBalanceViewModel(
            amount: useCase.fee,
            chainAsset: utilityChainAsset,
            balanceViewModelFactory: utilityBalanceViewModelFactory,
            locale: locale
        )

        let tipViewModel = buildBalanceViewModel(
            amount: useCase.tip,
            chainAsset: utilityChainAsset,
            balanceViewModelFactory: utilityBalanceViewModelFactory,
            locale: locale
        )

        return WalletSendConfirmViewModel(
            amountAttributedString: amountAttributedString,
            amountString: inputAmount,
            senderNameString: wallet.name,
            senderAddressString: senderAddress,
            receiverAddressString: receiverAddressString,
            priceString: priceString ?? "",
            feeAmountString: feeViewModel?.amount ?? "",
            feePriceString: feeViewModel?.price ?? "",
            tipRequired: useCase.tip != nil,
            tipAmountString: tipViewModel?.amount ?? "",
            tipPriceString: tipViewModel?.price ?? "",
            showWarning: scamInfo != nil,
            symbolViewModel: symbolViewModel
        )
    }

    // MARK: - Private methods

    private func buildPriceString(
        useCase: TransferFlowUseCase,
        locale: Locale,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) -> String? {
        guard
            let chainAsset = useCase.selectedChainAsset,
            let amount = useCase.amount(),
            let balance = useCase.availableBalance
        else {
            return nil
        }

        let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency)

        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        ).value(for: locale)

        return viewModel.price
    }

    private func buildBalanceViewModel(
        amount: Decimal?,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        locale: Locale
    ) -> BalanceViewModelProtocol? {
        guard let amount else {
            return nil
        }
        let priceData = chainAsset.asset.getPrice(for: wallet.selectedCurrency)
        let viewModel = balanceViewModelFactory.balanceFromPrice(
            amount,
            priceData: priceData,
            usageCase: .detailsCrypto
        ).value(for: locale)
        return viewModel
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
