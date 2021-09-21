import UIKit
import SoraFoundation
import SoraUI

protocol AnalyticsMagentaButtonModel {
    func title(for locale: Locale) -> String
}

final class AnalyticsMagentaButton<T: AnalyticsMagentaButtonModel>: RoundedButton, Localizable {
    let model: T

    init(model: T) {
        self.model = model
        super.init(frame: .zero)

        setupColors()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization() {
        imageWithTitleView?.title = model.title(for: selectedLocale)
    }

    private func setupColors() {
        roundedBackgroundView?.cornerRadius = 30
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = R.color.colorAccent()!

        contentInsets = UIEdgeInsets(top: 5.5, left: 12, bottom: 5.5, right: 12)

        imageWithTitleView?.titleColor = R.color.colorTransparentText()
        imageWithTitleView?.highlightedTitleColor = .white
        imageWithTitleView?.titleFont = .capsTitle
    }
}
