import Foundation
import CommonWallet

final class TransactionHistoryConfigurator {
    private lazy var transactionCellStyle: TransactionCellStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.p1Paragraph,
                                    color: R.color.colorWhite()!)
        let amount = WalletTextStyle(font: UIFont.p1Paragraph,
                                     color: R.color.colorWhite()!)
        let style = WalletTransactionStatusStyle(icon: nil,
                                                 color: R.color.colorWhite()!)
        let container = WalletTransactionStatusStyleContainer(approved: style,
                                                              pending: style,
                                                              rejected: style)
        return TransactionCellStyle(backgroundColor: .clear,
                                    title: title,
                                    amount: amount,
                                    statusStyleContainer: container,
                                    increaseAmountIcon: nil,
                                    decreaseAmountIcon: nil,
                                    separatorColor: .clear)
    }()

    private lazy var headerStyle: TransactionHeaderStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.capsTitle,
                                    color: R.color.colorWhite()!)
        return TransactionHeaderStyle(background: .clear,
                                      title: title,
                                      separatorColor: .clear,
                                      upppercased: true)
    }()

    func configure(builder: HistoryModuleBuilderProtocol) {
        builder
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(historyViewStyle: HistoryViewStyle.fearless)
            .with(transactionCellStyle: transactionCellStyle)
            .with(transactionHeaderStyle: headerStyle)
            .with(supportsFilter: false)
            .with(includesFeeInAmount: false)
    }
}
