import Foundation

class SwipeCellButton: VerticalContentButton, SwipeButtonProtocol {
    init(type: SwipableCellButtonType) {
        self.type = type
        super.init(frame: .zero)
        tag = type.rawValue
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var type: SwipableCellButtonType
}

extension VerticalContentButton {
    static func createSendButton(locale: Locale?) -> SwipeCellButton {
        let title = R.string.localizable
            .commonActionSend(preferredLanguages: locale?.rLanguages)
        let button = SwipeCellButton(type: .send)
        button.setImage(R.image.iconSwipeSend(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.setTitle(title, for: .normal)
        return button
    }

    static func createReceiveButton(locale: Locale?) -> SwipeCellButton {
        let title = R.string.localizable
            .commonActionReceive(preferredLanguages: locale?.rLanguages)
        let button = SwipeCellButton(type: .receive)
        button.setImage(R.image.iconSwipeReceive(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.setTitle(title, for: .normal)
        return button
    }

    static func createTeleportButton(locale: Locale?) -> SwipeCellButton {
        let title = R.string.localizable
            .swipableCellButtonTeleport(preferredLanguages: locale?.rLanguages)
        let button = SwipeCellButton(type: .teleport)
        button.setImage(R.image.iconSwipeTeleport(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.setTitle(title, for: .normal)
        return button
    }

    static func createHideButton(locale: Locale?) -> SwipeCellButton {
        let title = R.string.localizable
            .swipableCellButtonHide(preferredLanguages: locale?.rLanguages)
        let button = SwipeCellButton(type: .hide)
        button.setImage(R.image.iconSwipeHide(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.setTitle(title, for: .normal)
        return button
    }

    static func createShowButton(locale: Locale?) -> SwipeCellButton {
        let title = R.string.localizable
            .commonShow(preferredLanguages: locale?.rLanguages)
        let button = SwipeCellButton(type: .show)
        button.setImage(R.image.iconSwipeHide(), for: .normal)
        button.titleLabel?.font = .p2Paragraph
        button.setTitle(title, for: .normal)
        return button
    }
}
