import Foundation
import CommonWallet
import SoraFoundation

final class TransactionHistoryConfigurator {
    private lazy var transactionCellStyle: TransactionCellStyleProtocol = {
        let title = WalletTextStyle(
            font: UIFont.p1Paragraph,
            color: R.color.colorWhite()!
        )
        let amount = WalletTextStyle(
            font: UIFont.p1Paragraph,
            color: R.color.colorWhite()!
        )
        let style = WalletTransactionStatusStyle(
            icon: nil,
            color: R.color.colorWhite()!
        )
        let container = WalletTransactionStatusStyleContainer(
            approved: style,
            pending: style,
            rejected: style
        )
        return TransactionCellStyle(
            backgroundColor: .clear,
            title: title,
            amount: amount,
            statusStyleContainer: container,
            increaseAmountIcon: nil,
            decreaseAmountIcon: nil,
            separatorColor: .clear
        )
    }()

    private lazy var headerStyle: TransactionHeaderStyleProtocol = {
        let title = WalletTextStyle(
            font: UIFont.capsTitle,
            color: R.color.colorWhite()!
        )
        return TransactionHeaderStyle(
            background: .clear,
            title: title,
            separatorColor: .clear,
            upppercased: true
        )
    }()

    let viewModelFactory: TransactionHistoryViewModelFactory

    init(
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        assets: [WalletAsset],
        chain: Chain
    ) {
        viewModelFactory = TransactionHistoryViewModelFactory(
            amountFormatterFactory: amountFormatterFactory,
            dateFormatter: DateFormatter.txHistory,
            assets: assets,
            chain: chain
        )
    }

    func configure(builder: HistoryModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable
                .walletHistoryTitleV1(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(itemViewModelFactory: viewModelFactory)
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(historyViewStyle: HistoryViewStyle.fearless)
            .with(transactionCellStyle: transactionCellStyle)
            .with(cellClass: HistoryItemTableViewCell.self, for: HistoryConstants.historyCellId)
            .with(transactionHeaderStyle: headerStyle)
            .with(supportsFilter: false)
            .with(includesFeeInAmount: false)
            .with(localizableTitle: title)
            .with(viewFactoryOverriding: WalletHistoryViewFactoryOverriding())
    }
}
