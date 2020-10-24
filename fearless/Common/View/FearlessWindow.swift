import UIKit
import SoraUI

final class FearlessWindow: UIWindow {
    private struct Constants {
        static let statusHeight: CGFloat = 9.0
        static let appearanceAnimationDuration: TimeInterval = 0.2
        static let changeAnimationDuration: TimeInterval = 0.2
        static let dissmissAnimationDuration: TimeInterval = 0.2
    }

    private var statusView: ApplicationStatusView?

    override func addSubview(_ view: UIView) {
        super.addSubview(view)

        bringStatusToFront()
    }

    override func bringSubviewToFront(_ view: UIView) {
        super.bringSubviewToFront(view)

        bringStatusToFront()
    }

    private func bringStatusToFront() {
        if let view = subviews.first(where: { $0 is ApplicationStatusView }) {
            super.bringSubviewToFront(view)
        }
    }

    private func apply(style: ApplicationStatusStyle, to view: ApplicationStatusView) {
        view.backgroundColor = style.backgroundColor
        view.titleLabel.textColor = style.titleColor
        view.titleLabel.font = style.titleFont
    }

    private func prepareStatusView() -> ApplicationStatusView {
        let topMargin = UIApplication.shared.statusBarFrame.size.height
        let width = UIApplication.shared.statusBarFrame.size.width
        let height = topMargin + Constants.statusHeight

        let origin = CGPoint(x: 0.0, y: -height)
        let frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
        let imageWithTitleView = ApplicationStatusView(frame: frame)
        imageWithTitleView.contentInsets = UIEdgeInsets(top: topMargin / 2.0, left: 0, bottom: 3, right: 0)

        return imageWithTitleView
    }

    private func changeStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        let closure = {
            if let title = title {
                statusView.titleLabel.text = title
            }

            if let style = style {
                self.apply(style: style, to: statusView)
            }
        }

        if animated {
            BlockViewAnimator(duration: Constants.changeAnimationDuration).animate(block: closure,
                                                                                   completionBlock: nil)
        } else {
            closure()
        }
    }
}

extension FearlessWindow: ApplicationStatusPresentable {
    func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool) {
        if statusView != nil {
            changeStatus(title: title, style: style, animated: animated)
            return
        }

        let statusView = prepareStatusView()
        statusView.titleLabel.text = title
        apply(style: style, to: statusView)

        self.statusView = statusView

        var newFrame = statusView.frame
        newFrame.origin = .zero

        addSubview(statusView)

        if animated {
            BlockViewAnimator(duration: Constants.appearanceAnimationDuration).animate(block: {
                statusView.frame = newFrame
            }, completionBlock: nil)
        } else {
            statusView.frame = newFrame
        }
    }

    func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        var animationDelay: TimeInterval = 0.0

        if title != nil || style != nil {
            changeStatus(title: title, style: style, animated: animated)

            if animated {
                animationDelay = Constants.changeAnimationDuration
            }
        }

        self.statusView = nil

        if animated {
            var newFrame = statusView.frame
            newFrame.origin.y = -newFrame.height

            BlockViewAnimator(duration: Constants.dissmissAnimationDuration,
                              delay: 2 * animationDelay).animate(block: {
                statusView.frame = newFrame
            }, completionBlock: { _ in
                statusView.removeFromSuperview()
            })

        } else {
            statusView.removeFromSuperview()
        }
    }
}
