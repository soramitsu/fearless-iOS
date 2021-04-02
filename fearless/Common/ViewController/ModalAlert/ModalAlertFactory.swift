import UIKit
import SoraUI

struct ModalAlertFactory {
    static func createSuccessAlert(_ title: String) -> UIViewController {
        let contentView = ImageWithTitleView()
        contentView.iconImage = R.image.iconValidBig()
        contentView.title = title
        contentView.spacingBetweenLabelAndIcon = 8.0
        contentView.layoutType = .verticalImageFirst
        contentView.titleColor = R.color.colorWhite()!
        contentView.titleFont = UIFont.p2Paragraph

        let contentWidth = contentView.intrinsicContentSize.width + 24.0

        let controller = UIViewController()
        controller.view = contentView

        let preferredSize = CGSize(
            width: max(160.0, contentWidth),
            height: 87.0
        )

        let style = ModalAlertPresentationStyle(
            backgroundColor: R.color.colorAlmostBlack()!,
            backdropColor: .clear,
            cornerRadius: 8.0
        )

        let configuration = ModalAlertPresentationConfiguration(
            style: style,
            preferredSize: preferredSize,
            dismissAfterDelay: 1.5,
            completionFeedback: .success
        )

        controller.modalTransitioningFactory = ModalAlertPresentationFactory(configuration: configuration)
        controller.modalPresentationStyle = .custom

        return controller
    }

    static func createMultilineSuccessAlert(
        _ title: String,
        dissmisAfter timeInterval: TimeInterval = 4.0
    ) -> UIViewController {
        let contentView = MultilineImageWithTitleView()
        contentView.verticalSpacing = 8.0
        contentView.titleLabel.textColor = R.color.colorWhite()
        contentView.titleLabel.font = UIFont.p2Paragraph
        contentView.titleLabel.text = title
        contentView.titleLabel.textAlignment = .center
        contentView.imageView.image = R.image.iconValidBig()
        contentView.contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)

        contentView.forceSizeCalculation()

        let controller = UIViewController()
        controller.view = contentView

        let style = ModalAlertPresentationStyle(
            backgroundColor: R.color.colorAlmostBlack()!,
            backdropColor: .clear,
            cornerRadius: 8.0
        )

        let preferredSize = contentView.intrinsicContentSize
        let configuration = ModalAlertPresentationConfiguration(
            style: style,
            preferredSize: preferredSize,
            dismissAfterDelay: timeInterval,
            completionFeedback: .success
        )

        controller.modalTransitioningFactory = ModalAlertPresentationFactory(configuration: configuration)
        controller.modalPresentationStyle = .custom

        return controller
    }
}
