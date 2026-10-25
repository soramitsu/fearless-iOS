import Foundation
import UIKit

struct SheetAlertPresentableActionStyle {
    let backgroundColor: UIColor
    let titleColor: UIColor

    static let defaultStyle: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: R.color.colorWhite8()!,
            titleColor: R.color.colorWhite()!
        )
    }()

    static let warningStyle: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: R.color.colorWhite8()!,
            titleColor: R.color.colorPink()!
        )
    }()

    static let pinkBackgroundWhiteText: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: R.color.colorPink()!,
            titleColor: R.color.colorWhite()!
        )
    }()

    static let grayBackgroundPinkText: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: R.color.colorSemiBlack()!,
            titleColor: R.color.colorPink()!
        )
    }()

    static let grayBackgroundWhiteText: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: R.color.colorSemiBlack()!,
            titleColor: R.color.colorWhite()!
        )
    }()

    static let clearBackgroundWhiteText: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: .clear,
            titleColor: R.color.colorWhite()!
        )
    }()

    static let clearBackgroundPinkText: SheetAlertPresentableActionStyle = {
        SheetAlertPresentableActionStyle(
            backgroundColor: .clear,
            titleColor: R.color.colorPink()!
        )
    }()
}

struct SheetAlertPresentableAction {
    let title: String
    let button: TriangularedButton
    let handler: (() -> Void)?
    let handlerAfterDismissal: Bool
    let beforeDismissal: (() -> Void)?
    let style: SheetAlertPresentableActionStyle

    init(
        title: String,
        style: SheetAlertPresentableActionStyle = .defaultStyle,
        button: TriangularedButton = UIFactory.default.createMainActionButton(),
        handlerAfterDismissal: Bool = false,
        beforeDismissal: (() -> Void)? = nil,
        handler: (() -> Void)? = nil
    ) {
        self.title = title
        self.button = button
        self.handler = handler
        self.handlerAfterDismissal = handlerAfterDismissal
        self.beforeDismissal = beforeDismissal
        self.style = style
    }
}

struct SheetAlertPresentableViewModel {
    let presentationID: UUID
    let title: String
    let titleStyle: SheetAlertPresentableStyle
    let message: String?
    let messageStyle: SheetAlertPresentableStyle?
    let actions: [SheetAlertPresentableAction]
    let isInfo: Bool
    let closeAction: String?
    let dismissCompletion: (() -> Void)?
    let icon: UIImage?
    let actionAxis: NSLayoutConstraint.Axis
    let scrollableContent: Bool
    /// False leaves the actions as the only way to close the sheet.
    let showsCloseButton: Bool

    init(
        title: String,
        titleStyle: SheetAlertPresentableStyle = .defaultTitle,
        message: String?,
        messageStyle: SheetAlertPresentableStyle? = .defaultSubtitle,
        actions: [SheetAlertPresentableAction],
        isInfo: Bool = false,
        closeAction: String?,
        dismissCompletion: (() -> Void)? = nil,
        icon: UIImage? = R.image.iconWarning(),
        actionAxis: NSLayoutConstraint.Axis = .vertical,
        scrollableContent: Bool = false,
        showsCloseButton: Bool = true,
        presentationID: UUID = UUID()
    ) {
        self.title = title
        self.titleStyle = titleStyle
        self.message = message
        self.messageStyle = messageStyle
        self.actions = actions
        self.isInfo = isInfo
        self.closeAction = closeAction
        self.dismissCompletion = dismissCompletion
        self.icon = icon
        self.actionAxis = actionAxis
        self.scrollableContent = scrollableContent
        self.showsCloseButton = showsCloseButton
        self.presentationID = presentationID
    }
}

protocol SheetAlertPresentable: BaseErrorPresentable, ErrorPresentable {
    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    )

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    )

    func presentInfo(
        message: String?,
        title: String,
        from view: ControllerBackedProtocol?
    )
}

extension SheetAlertPresentable {
    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(
            configuration: .fearlessBlur,
            shouldDissmissWhenTapOnBlurArea: viewModel.dismissCompletion == nil
        )
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction] = []
    ) {
        guard let controller = view?.controller else {
            return
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: actions,
            isInfo: false,
            closeAction: closeAction
        )
        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }

    func presentInfo(
        message: String?,
        title: String,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            isInfo: true,
            closeAction: nil,
            icon: R.image.iconInfoGrayFill()
        )
        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }
}
