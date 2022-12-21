import Foundation
import UIKit

protocol SlippageToleranceViewModelFactoryProtocol {
    func buildViewModel(
        with value: Float,
        locale: Locale
    ) -> SlippageToleranceViewModel
}

final class SlippageToleranceViewModelFactory: SlippageToleranceViewModelFactoryProtocol {
    func buildViewModel(
        with value: Float,
        locale: Locale
    ) -> SlippageToleranceViewModel {
        var viewModel: SlippageToleranceViewModel
        var image: UIImage?
        var warningText: String = ""

        let mutableAttributedString = NSMutableAttributedString()
        let formatedValue = String(format: "%.2f", value)
        let valueAttributedString = NSAttributedString(string: formatedValue + "%")
        mutableAttributedString.append(valueAttributedString)

        switch Double(value) {
        case 0 ... 0.1:
            warningText = R.string.localizable
                .polkaswapSettingsSlippadgeFail(preferredLanguages: locale.rLanguages)
            image = R.image.iconWarningBig()
        case 5 ... 10:
            warningText = R.string.localizable
                .polkaswapSettingsSlippadgeFrontrun(preferredLanguages: locale.rLanguages)
            image = R.image.iconWarningBig()
        default:
            break
        }

        let warningAttributedString = NSAttributedString(string: warningText)
        mutableAttributedString.append(warningAttributedString)

        mutableAttributedString.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorOrange()!,
            range: (mutableAttributedString.string as NSString).range(of: warningText)
        )

        mutableAttributedString.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.p1Paragraph,
            range: (mutableAttributedString.string as NSString).range(of: warningText)
        )

        viewModel = SlippageToleranceViewModel(
            value: value,
            attributedText: mutableAttributedString,
            image: image
        )

        return viewModel
    }
}
