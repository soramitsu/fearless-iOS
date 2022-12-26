import Foundation
import UIKit

protocol SlippageToleranceViewModelFactoryProtocol {
    func buildViewModel(
        with value: Float,
        locale: Locale
    ) -> SlippageToleranceViewModel
}

final class SlippageToleranceViewModelFactory: SlippageToleranceViewModelFactoryProtocol {
    private enum Constants {
        static let imageWidth: CGFloat = 13
        static let imageHeight: CGFloat = 12
        static let imageVerticalPosition: CGFloat = 2
    }

    func buildViewModel(
        with value: Float,
        locale: Locale
    ) -> SlippageToleranceViewModel {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        var viewModel: SlippageToleranceViewModel
        var warningText: String = ""

        var mutableAttributedString: NSMutableAttributedString?
        var sliderValue = value
        switch Double(value) {
        case 0 ... 0.1:
            mutableAttributedString = NSMutableAttributedString()
            warningText = R.string.localizable
                .polkaswapSettingsSlippadgeFail(preferredLanguages: locale.rLanguages)
        case 5 ... 10:
            mutableAttributedString = NSMutableAttributedString()
            warningText = R.string.localizable
                .polkaswapSettingsSlippadgeFrontrun(preferredLanguages: locale.rLanguages)
        case _ where value > 10:
            sliderValue = 10
        default:
            break
        }

        var formatedValue = formatter.string(from: sliderValue as NSNumber) ?? ""
        formatedValue.append("%")
        if let mutableAttributedString = mutableAttributedString {
            let warningAttributedString = NSAttributedString(string: warningText)

            let imageAttachment = NSTextAttachment()
            imageAttachment.image = R.image.iconWarning()
            imageAttachment.bounds = CGRect(
                x: 0,
                y: -Constants.imageVerticalPosition,
                width: Constants.imageWidth,
                height: Constants.imageHeight
            )
            let imageString = NSAttributedString(attachment: imageAttachment)
            mutableAttributedString.append(imageString)
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
        }

        viewModel = SlippageToleranceViewModel(
            value: sliderValue,
            textFieldText: formatedValue,
            labelAttributedString: mutableAttributedString,
            image: nil
        )

        return viewModel
    }
}
