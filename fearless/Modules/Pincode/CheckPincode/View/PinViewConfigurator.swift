import Foundation
import SoraUI

enum PinViewConfigurator {
    static func defaultPinView() -> PinView {
        let pinView = PinView()
        pinView.mode = .securedInput
        pinView.characterFieldsView?.numberOfCharacters = 6
        pinView.securedCharacterFieldsView?.numberOfCharacters = 6
        pinView.characterFieldsView?.fieldStrokeWidth = 2
        pinView.securedCharacterFieldsView?.fieldSize = CGSize(width: 15, height: 15)
        pinView.characterFieldsView?.fieldSpacing = 24
        pinView.securedCharacterFieldsView?.fieldSpacing = 24
        pinView.numpadView?.shadowRadius = 36
        pinView.numpadView?.keyRadius = 36
        pinView.numpadView?.verticalSpacing = 15
        pinView.numpadView?.horizontalSpacing = 22
        pinView.numpadView?.backspaceIcon =
            R.image.pinBackspace()?.tinted(with: R.color.colorWhite()!)?.withRenderingMode(.automatic)
        pinView.numpadView?.fillColor = .clear
        pinView.numpadView?.highlightedFillColor = R.color.colorCellSelection()
        pinView.numpadView?.titleColor = R.color.colorWhite()
        pinView.numpadView?.highlightedTitleColor = UIColor(
            red: 255 / 255,
            green: 255 / 255,
            blue: 255 / 255,
            alpha: 0.5
        )
        pinView.numpadView?.titleFont = R.font.soraRc0040417Regular(size: 25)!
        pinView.securedCharacterFieldsView?.strokeWidth = 2
        pinView.securedCharacterFieldsView?.fieldRadius = 6
        pinView.verticalSpacing = 79
        pinView.securedCharacterFieldsView?.fillColor = R.color.colorWhite()!
        pinView.securedCharacterFieldsView?.strokeColor = R.color.colorWhite()!
        pinView.numpadView?.shadowOpacity = 0
        pinView.numpadView?.shadowRadius = 0
        pinView.numpadView?.shadowOffset = CGSize(width: 0, height: 1)
        pinView.numpadView?.shadowColor = UIColor(
            red: 47 / 255,
            green: 128 / 255,
            blue: 124 / 255,
            alpha: 0.3
        )
        pinView.numpadView?.supportsAccessoryControl = true
        return pinView
    }
}
