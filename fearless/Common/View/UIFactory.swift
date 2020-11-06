import UIKit
import SoraUI

struct UIConstants {
    static let actionBottomInset: CGFloat = 24.0
    static let actionHeight: CGFloat = 52.0
    static let mainAccessoryActionsSpacing: CGFloat = 16.0
    static let horizontalInset: CGFloat = 16.0
    static let triangularedViewHeight: CGFloat = 52.0
    static let expandableViewHeight: CGFloat = 50.0
    static let formSeparatorWidth: CGFloat = 0.5
    static let triangularedIconLargeRadius: CGFloat = 12.0
    static let triangularedIconSmallRadius: CGFloat = 9.0
}

protocol UIFactoryProtocol {
    func createMainActionButton() -> TriangularedButton
    func createAccessoryButton() -> TriangularedButton
    func createDetailsView(with layout: DetailsTriangularedView.Layout,
                           filled: Bool) -> DetailsTriangularedView
    func createExpandableActionControl() -> ExpandableActionControl
    func createSeparatorView() -> UIView
}

final class UIFactory: UIFactoryProtocol {
    func createMainActionButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }

    func createAccessoryButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applyAccessoryStyle()
        return button
    }

    func createDetailsView(with layout: DetailsTriangularedView.Layout,
                           filled: Bool) -> DetailsTriangularedView {
        let view = DetailsTriangularedView()
        view.layout = layout

        if !filled {
            view.fillColor = .clear
            view.highlightedFillColor = .clear
            view.strokeColor = R.color.colorGray()!
            view.highlightedStrokeColor = R.color.colorGray()!
            view.borderWidth = 1.0
        } else {
            view.fillColor = R.color.colorDarkGray()!
            view.highlightedFillColor = R.color.colorDarkGray()!
            view.strokeColor = .clear
            view.highlightedStrokeColor = .clear
            view.borderWidth = 0.0
        }

        switch layout {
        case .largeIconTitleSubtitle, .singleTitle:
            view.iconRadius = UIConstants.triangularedIconLargeRadius
        case .smallIconTitleSubtitle:
            view.iconRadius = UIConstants.triangularedIconSmallRadius
        }

        view.titleLabel.textColor = R.color.colorLightGray()!
        view.titleLabel.font = UIFont.p2Paragraph
        view.subtitleLabel?.textColor = R.color.colorWhite()!
        view.subtitleLabel?.font = UIFont.p1Paragraph
        view.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 8.0, right: 16.0)

        return view
    }

    func createExpandableActionControl() -> ExpandableActionControl {
        let view = ExpandableActionControl()
        view.layoutType = .flexible
        view.titleLabel.textColor = R.color.colorWhite()
        view.titleLabel.font = UIFont.p1Paragraph
        view.plusIndicator.strokeColor = R.color.colorWhite()!

        return view
    }

    func createSeparatorView() -> UIView {
        let view = UIView()
        view.backgroundColor = R.color.colorDarkGray()!
        return view
    }
}
