import Foundation
import CommonWallet

final class TransactionDetailsFormViewModelBinder: WalletFormViewModelBinderOverriding {
    private struct Constants {
        static let separatorWidth: CGFloat = 0.5
        static let contentInsets: UIEdgeInsets = UIEdgeInsets(top: 14.0,
                                                              left: 0.0,
                                                              bottom: 14.0,
                                                              right: 0.0)
        static let detailsHeaderInsets = UIEdgeInsets(top: 18.0,
                                                      left: 0.0,
                                                      bottom: 0.0,
                                                      right: 0.0)
        static let horizontalSpacing: CGFloat = 10.0
    }

    func bind(viewModel: WalletNewFormDetailsViewModel, to view: WalletFormDetailsViewProtocol) -> Bool {
        let style = WalletFormCellStyle.fearless

        let separatorStyle = WalletStrokeStyle(color: style.separator,
                                               lineWidth: Constants.separatorWidth)

        view.style = WalletFormDetailsViewStyle(title: style.title,
                                                separatorStyle: separatorStyle,
                                                contentInsets: Constants.contentInsets,
                                                titleHorizontalSpacing: Constants.horizontalSpacing,
                                                detailsHorizontalSpacing: Constants.horizontalSpacing,
                                                details: style.details,
                                                detailsAlignment: .detailsIcon)

        view.bind(viewModel: viewModel)

        return true
    }
}
