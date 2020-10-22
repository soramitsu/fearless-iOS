import Foundation
import CommonWallet
import SoraFoundation

final class TransactionDetailsViewModelFactory {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]

    init(assets: [WalletAsset],
         dateFormatter: LocalizableResource<DateFormatter>,
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.dateFormatter = dateFormatter
        self.amountFormatterFactory = amountFormatterFactory
    }

    private func populateStatus(into viewModelList: inout [WalletFormViewBindingProtocol],
                                data: AssetTransactionData) {
        let viewModel: WalletNewFormDetailsViewModel

        let title = "Status"

        switch data.status {
        case .commited:
            viewModel = WalletNewFormDetailsViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: "Completed",
                                                      detailsIcon: R.image.iconValid())
        case .pending:
            viewModel = WalletNewFormDetailsViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: "Pengin",
                                                      detailsIcon: R.image.iconTxPending())
        case .rejected:
            viewModel = WalletNewFormDetailsViewModel(title: title,
                                                      titleIcon: nil,
                                                      details: "Failed",
                                                      detailsIcon: R.image.iconInvalid())
        }

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateTime(into viewModelList: inout [WalletFormViewBindingProtocol],
                              data: AssetTransactionData,
                              locale: Locale) {
        let transactionDate = Date(timeIntervalSince1970: TimeInterval(data.timestamp))

        let timeDetails = dateFormatter.value(for: locale).string(from: transactionDate)

        let viewModel = WalletNewFormDetailsViewModel(title: "Date",
                                                      titleIcon: nil,
                                                      details: timeDetails,
                                                      detailsIcon: nil)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateAmount(into viewModelList: inout [WalletFormViewBindingProtocol],
                                data: AssetTransactionData,
                                locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let amount = data.amount.decimalValue

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let displayAmount = formatter.value(for: locale).string(from: amount) else {
            return
        }

        let viewModel = WalletNewFormDetailsViewModel(title: "Amount",
                                                      titleIcon: nil,
                                                      details: displayAmount,
                                                      detailsIcon: nil)

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    private func populateFeeAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                                   data: AssetTransactionData,
                                   locale: Locale) {
        let asset = assets.first(where: { $0.identifier == data.assetId })

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in data.fees where fee.assetId == data.assetId {

            guard let amount = formatter.string(from: fee.amount.decimalValue) else {
                continue
            }

            let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)

            let viewModel = WalletNewFormDetailsViewModel(title: title,
                                                          titleIcon: nil,
                                                          details: amount,
                                                          detailsIcon: nil)

            let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
            viewModelList.append(separator)
        }
    }
}

extension TransactionDetailsViewModelFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(data: AssetTransactionData,
                                         commandFactory: WalletCommandFactoryProtocol,
                                         locale: Locale) -> [WalletFormViewBindingProtocol]? {
        var viewModels: [WalletFormViewBindingProtocol] = []

        populateStatus(into: &viewModels, data: data)
        populateTime(into: &viewModels, data: data, locale: locale)
        populateAmount(into: &viewModels, data: data, locale: locale)
        populateFeeAmount(in: &viewModels, data: data, locale: locale)

        return viewModels
    }

    func createAccessoryViewModelFromTransaction(data: AssetTransactionData,
                                                 commandFactory: WalletCommandFactoryProtocol,
                                                 locale: Locale) -> AccessoryViewModelProtocol? {
        nil
    }
}
