import UIKit

final class ExportGenericViewModelBinder: ExportGenericViewModelBinding {
    let uiFactory: UIFactoryProtocol

    init(uiFactory: UIFactoryProtocol) {
        self.uiFactory = uiFactory
    }

    func bind(stringViewModel: ExportStringViewModel, locale: Locale) -> UIView {
        let detailsView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        detailsView.translatesAutoresizingMaskIntoConstraints = false

        detailsView.heightAnchor
            .constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true

        detailsView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
        detailsView.title = stringViewModel.option.titleForLocale(locale)
        detailsView.subtitle = stringViewModel.data

        return detailsView
    }

    func bind(mnemonicViewModel: ExportMnemonicViewModel, locale: Locale) -> UIView {
        let title = R.string.localizable.exportMnemonicHint(preferredLanguages: locale.rLanguages)
        let icon = R.image.iconAlert()

        let mnemonicView = uiFactory.createTitledMnemonicView(title, icon: icon)
        mnemonicView.contentView.bind(words: mnemonicViewModel.mnemonic, columnsCount: 2)

        return mnemonicView
    }
}
