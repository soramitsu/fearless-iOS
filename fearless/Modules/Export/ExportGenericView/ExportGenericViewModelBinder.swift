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
        detailsView.title = stringViewModel.option.titleForLocale(locale, ethereumBased: stringViewModel.ethereumBased)
        detailsView.subtitle = stringViewModel.data

        return detailsView
    }

    func bind(multilineViewModel: ExportStringViewModel, locale: Locale) -> UIView {
        let detailsView = uiFactory.createMultilinedTriangularedView()

        detailsView.titleLabel.text = multilineViewModel.option.titleForLocale(locale, ethereumBased: multilineViewModel.ethereumBased)
        detailsView.subtitleLabel.text = multilineViewModel.data

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
