import Foundation
import CommonWallet
import FearlessUtils

final class TransferConfirmViewModelFactory {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let assets: [WalletAsset]
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset], amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateAsset(in viewModelList: inout [WalletFormViewBindingProtocol],
                       payload: ConfirmationPayload,
                       locale: Locale) {
        guard
            let asset = assets
                .first(where: { $0.identifier == payload.transferInfo.asset }),
            let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return
        }

        let headerTitle = R.string.localizable.walletSendAssetTitle(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormDetailsHeaderModel(title: headerTitle)
        viewModelList.append(headerViewModel)

        let subtitle: String = R.string.localizable
            .walletSendBalanceTitle(preferredLanguages: locale.rLanguages)

        let context = TransferContext(context: payload.transferInfo.context ?? [:])

        let amountFormatter = amountFormatterFactory.createTokenFormatter(for: asset)
        let details = amountFormatter.value(for: locale).string(from: context.balance) ?? ""

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)
        let tokenViewModel = WalletTokenViewModel(title: assetId.titleForLocale(locale),
                                                  subtitle: subtitle,
                                                  details: details,
                                                  icon: assetId.icon,
                                                  state: selectedState,
                                                  detailsCommand: nil)
        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateFee(in viewModelList: inout [WalletFormViewBindingProtocol],
                     payload: ConfirmationPayload,
                     locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        for fee in payload.transferInfo.fees {
            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.value(for: locale).string(from: decimalAmount) else {
                return
            }

            let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)
            let viewModel = WalletNewFormDetailsViewModel(title: title,
                                                          titleIcon: nil,
                                                          details: amount,
                                                          detailsIcon: nil)
            viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
        }
    }

    func populateSendingAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createInputFormatter(for: asset)

        let decimalAmount = payload.transferInfo.amount.decimalValue

        guard let amount = formatter.value(for: locale).string(from: decimalAmount as NSNumber) else {
            return
        }

        let title = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title, amount: amount)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: .none))
    }

    func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                          payload: ConfirmationPayload,
                          locale: Locale) {
        let headerTitle = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)
        let headerViewModel = WalletFormDetailsHeaderModel(title: headerTitle)
        viewModelList.append(headerViewModel)

        let iconGenerator = PolkadotIconGenerator()
        let icon = try? iconGenerator.generateFromAddress(payload.receiverName)
            .imageWithFillColor(R.color.colorWhite()!,
                                size: CGSize(width: 24.0, height: 24.0),
                                contentScale: UIScreen.main.scale)

        let alertTitle = R.string.localizable
            .commonCopied(preferredLanguages: locale.rLanguages)
        let copyCommand = WalletCopyCommand(copyingString: payload.receiverName,
                                            alertTitle: alertTitle)
        copyCommand.commandFactory = commandFactory

        let viewModel = WalletAccountViewModel(text: payload.receiverName,
                                               icon: icon,
                                               copyCommand: copyCommand)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }
}

extension TransferConfirmViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(_ payload: ConfirmationPayload,
                                     locale: Locale) -> [WalletFormViewBindingProtocol]? {
        var viewModelList: [WalletFormViewBindingProtocol] = []

        populateAsset(in: &viewModelList, payload: payload, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, locale: locale)
        populateFee(in: &viewModelList, payload: payload, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(_ payload: ConfirmationPayload,
                                             locale: Locale) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return nil
        }

        var decimalAmount = payload.transferInfo.amount.decimalValue

        for fee in payload.transferInfo.fees {
            decimalAmount += fee.value.decimalValue
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let amount = formatter.value(for: locale).string(from: decimalAmount) else {
            return nil
        }

        let actionTitle = R.string.localizable.walletSendConfirmTitle(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)

        return TransferConfirmAccessoryViewModel(title: title,
                                                 icon: nil,
                                                 action: actionTitle,
                                                 numberOfLines: 1,
                                                 amount: amount)
    }
}
