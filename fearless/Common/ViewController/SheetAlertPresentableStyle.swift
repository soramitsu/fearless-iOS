import Foundation
import UIKit

struct SheetAlertPresentableStyle {
    let font: UIFont
    let textColor: UIColor
    let backgroundColor: UIColor?
}

extension SheetAlertPresentableStyle {
    static let defaultTitle = SheetAlertPresentableStyle(
        font: .h3Title,
        textColor: R.color.colorWhite()!,
        backgroundColor: nil
    )

    static let defaultSubtitle = SheetAlertPresentableStyle(
        font: .p0Paragraph,
        textColor: R.color.colorStrokeGray()!,
        backgroundColor: nil
    )

    static let defaultAction = SheetAlertPresentableStyle(
        font: .h4Title,
        textColor: R.color.colorWhite()!,
        backgroundColor: R.color.colorPink()
    )
}
