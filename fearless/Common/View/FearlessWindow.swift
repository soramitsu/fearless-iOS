import UIKit
import SoraUI

final class FearlessWindow: UIWindow {
    private enum Constants {
        static let statusHeight: CGFloat = 9.0
        static let appearanceAnimationDuration: TimeInterval = 0.2
        static let changeAnimationDuration: TimeInterval = 0.2
        static let dismissAnimationDuration: TimeInterval = 0.2
        static let autoDismissDelay: TimeInterval = 2.0
    }

    private var statusView: ApplicationStatusView?
    private lazy var statusViewBottomInset: CGFloat = {
        var bottomInset: CGFloat = UIConstants.statusViewHeight
        // The iPad sidebar tabs can hide the tab bar; iPhone keeps its custom bar here.
        if let tabBarController = rootViewController as? MainTabBarViewController,
           !(tabBarController.usesAdaptiveTabs && tabBarController.tabBar.isHidden) {
            bottomInset += tabBarController.tabBar.frame.height
        }
        return bottomInset
    }()

    /// The view the user last started touching. iPad popovers anchor to it so an
    /// action sheet opens next to the control that requested it.
    private(set) weak var lastTouchedView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()

        // Navigation and tab containers center their own screens; a plain root
        // screen such as the PIN pad is centered here.
        if let root = rootViewController, !(root is UINavigationController), !(root is UITabBarController) {
            root.applyAdaptiveContentColumn(
                containerWidth: bounds.width,
                containerSafeArea: safeAreaInsets,
                traits: traitCollection
            )
        }
    }

    override func sendEvent(_ event: UIEvent) {
        if event.type == .touches,
           let touch = event.allTouches?.first(where: { $0.phase == .began }),
           let view = touch.view {
            lastTouchedView = view
        }

        super.sendEvent(event)
    }

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

    private func prepareStatusView() -> ApplicationStatusView {
        let statusView = ApplicationStatusView()
        addSubview(statusView)
        statusView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(statusViewBottomInset)
        }
        layoutIfNeeded()

        return statusView
    }

    private func changeStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        let closure = {
            statusView.bind(viewModel: viewModel)
        }

        if animated {
            BlockViewAnimator(duration: Constants.changeAnimationDuration).animate(
                block: closure,
                completionBlock: nil
            )
        } else {
            closure()
        }
    }
}

extension FearlessWindow: ApplicationStatusPresentable {
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) {
        if statusView != nil {
            changeStatus(with: viewModel, animated: animated)
            return
        }

        let statusView = prepareStatusView()
        statusView.bind(viewModel: viewModel)

        self.statusView = statusView
        addSubview(statusView)

        if animated {
            BlockViewAnimator(duration: Constants.appearanceAnimationDuration).animate(block: { [weak self] in
                guard let strongSelf = self else { return }
                statusView.snp.updateConstraints { make in
                    make.top.equalTo(strongSelf.safeAreaLayoutGuide.snp.bottom).inset(strongSelf.statusViewBottomInset)
                }
                strongSelf.layoutIfNeeded()
            }, completionBlock: nil)
        } else {
            layoutIfNeeded()
        }

        if viewModel.autoDismissing {
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.autoDismissDelay) {
                self.dismissStatus(with: nil, animated: true)
            }
        }
    }

    func dismissStatus(with viewModel: ApplicationStatusAlertEvent?, animated: Bool) {
        guard let statusView = statusView else {
            return
        }

        var animationDelay: TimeInterval = 0.0

        if let viewModel = viewModel {
            changeStatus(with: viewModel, animated: animated)

            if animated {
                animationDelay = Constants.changeAnimationDuration
            }
        }

        self.statusView = nil

        if animated {
            BlockViewAnimator(
                duration: Constants.dismissAnimationDuration,
                delay: 2 * animationDelay
            ).animate(block: { [weak self] in
                guard let strongSelf = self else { return }
                statusView.snp.updateConstraints { make in
                    make.top.equalTo(strongSelf.safeAreaLayoutGuide.snp.bottom).offset(strongSelf.statusViewBottomInset)
                }
                strongSelf.layoutIfNeeded()
            }, completionBlock: { _ in
                statusView.removeFromSuperview()
            })

        } else {
            statusView.removeFromSuperview()
        }
    }
}
