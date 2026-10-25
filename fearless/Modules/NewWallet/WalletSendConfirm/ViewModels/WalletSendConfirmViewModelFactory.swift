import Foundation
import SSFModels

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
    let chain: ChainModel
    var accountCreationDepositViewModel: BalanceViewModelProtocol?
}

protocol WalletSendConfirmViewModelFactoryProtocol {
    func buildViewModel(
        parameters: WalletSendConfirmViewModelFactoryParameters
    ) -> WalletSendConfirmViewModel
}

class WalletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol {
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo

    init(amountFormatterFactory: AssetBalanceFormatterFactoryProtocol, assetInfo: AssetBalanceDisplayInfo) {
        self.amountFormatterFactory = amountFormatterFactory
        self.assetInfo = assetInfo
    }

    func buildViewModel(
        parameters: WalletSendConfirmViewModelFactoryParameters
    ) -> WalletSendConfirmViewModel {
        let formatter = amountFormatterFactory.createTokenFormatter(for: assetInfo, usageCase: .detailsCrypto)
        let inputAmount = formatter.value(for: parameters.locale).stringFromDecimal(parameters.amount) ?? ""
        let amountString = R.string.localizable.sendConfirmAmountTitle(
            inputAmount,
            preferredLanguages: parameters.locale.rLanguages
        )
        let amountAttributedString = NSMutableAttributedString(string: amountString)
        amountAttributedString.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorWhite()!.cgColor,
            range: (amountString as NSString).range(of: inputAmount)
        )
        let shadowColor = HexColorConverter.hexStringToUIColor(
            hex: parameters.assetModel.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            symbolViewModel: parameters.assetModel.icon.map { RemoteImageViewModel(url: $0) },
            shadowColor: shadowColor
        )
        return WalletSendConfirmViewModel(
            networkName: Self.networkName(chain: parameters.chain, asset: parameters.assetModel),
            networkIsTestnet: PortfolioTestnetChainList.bundled.isTestnet(parameters.chain),
            networkIcon: parameters.chain.icon.map { RemoteImageViewModel(url: $0) },
            amountAttributedString: amountAttributedString,
            amountString: inputAmount,
            senderNameString: parameters.wallet.name,
            senderAddressString: parameters.senderAccountViewModel?.name ?? "",
            receiverAddressString: parameters.receiverAccountViewModel?.name ?? "",
            priceString: parameters.assetBalanceViewModel?.price ?? "",
            feeAmountString: parameters.feeViewModel?.amount ?? "",
            feePriceString: parameters.feeViewModel?.price ?? "",
            tipRequired: parameters.tipRequired,
            tipAmountString: parameters.tipViewModel?.amount ?? "",
            tipPriceString: parameters.tipViewModel?.price ?? "",
            showWarning: parameters.scamInfo != nil,
            symbolViewModel: symbolViewModel,
            accountCreationAmountString: parameters.accountCreationDepositViewModel?.amount ?? "",
            accountCreationPriceString: parameters.accountCreationDepositViewModel?.price ?? ""
        )
    }

    static func networkName(chain: ChainModel, asset: AssetModel) -> String {
        switch asset.ethereumType {
        case .erc20: return chain.name + " · ERC-20"
        case .bep20: return chain.name + " · BEP-20"
        default: return chain.name
        }
    }
}
