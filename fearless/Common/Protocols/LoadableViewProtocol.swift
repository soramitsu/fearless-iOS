import UIKit
import SoraUI

protocol LoadableViewProtocol: class {
    var loadableContentView: UIView! { get }
    var shouldDisableInteractionWhenLoading: Bool { get }

    func didStartLoading()
    func didStopLoading()
}

struct LoadableViewProtocolConstants {
    static let activityIndicatorIdentifier: String = "LoadingIndicatorIdentifier"
    static let animationDuration = 0.35
}

extension LoadableViewProtocol where Self: UIViewController {
    var loadableContentView: UIView! {
        return view
    }

    var shouldDisableInteractionWhenLoading: Bool {
        return true
    }

    func didStartLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard activityIndicator == nil else {
            return
        }

        let newIndicator = FearlessLoadingViewFactory.createLoadingView()
        newIndicator.accessibilityIdentifier = LoadableViewProtocolConstants.activityIndicatorIdentifier
        newIndicator.frame = loadableContentView.bounds
        newIndicator.autoresizingMask = UIView.AutoresizingMask.flexibleWidth.union(.flexibleHeight)
        newIndicator.alpha = 0.0
        loadableContentView.addSubview(newIndicator)

        loadableContentView.isUserInteractionEnabled = shouldDisableInteractionWhenLoading

        newIndicator.startAnimating()

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration) {
            newIndicator.alpha = 1.0
        }
    }

    func didStopLoading() {
        let activityIndicator = loadableContentView.subviews.first {
            $0.accessibilityIdentifier == LoadableViewProtocolConstants.activityIndicatorIdentifier
        }

        guard let currentIndicator = activityIndicator as? LoadingView else {
            return
        }

        currentIndicator.accessibilityIdentifier = nil
        loadableContentView.isUserInteractionEnabled = true

        UIView.animate(withDuration: LoadableViewProtocolConstants.animationDuration,
                       animations: {
                        currentIndicator.alpha = 0.0
        }, completion: { _ in
            currentIndicator.stopAnimating()
            currentIndicator.removeFromSuperview()
        })
    }
}
