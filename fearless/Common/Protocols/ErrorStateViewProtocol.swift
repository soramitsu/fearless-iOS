import UIKit

protocol ErrorStateViewProtocol: AnyObject {
    var errorContentView: UIView! { get }
    func showError(_ error: Error, retryAction: @escaping () -> Void)
    func hideError()
}

extension ErrorStateViewProtocol where Self: UIViewController {
    var errorContentView: UIView! { view }

    func showError(_ error: Error, retryAction: @escaping () -> Void) {
        let existingErrorView = errorContentView.subviews.first {
            $0.accessibilityIdentifier == ErrorViewProtocolConstants.errorViewIdentifier
        }
        guard existingErrorView == nil else { return }

        let errorView = ErrorView()
        errorView.errorDescriptionLabel.text = error.localizedDescription
        errorView.retryButton.addAction(retryAction)

        errorView.accessibilityIdentifier = ErrorViewProtocolConstants.errorViewIdentifier
        errorContentView.addSubview(errorView)
        errorView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    func hideError() {
        let existingErrorView = errorContentView.subviews.first {
            $0.accessibilityIdentifier == ErrorViewProtocolConstants.errorViewIdentifier
        }
        guard let errorView = existingErrorView as? ErrorView else { return }

        errorView.accessibilityIdentifier = nil
        errorView.removeFromSuperview()
    }
}

private enum ErrorViewProtocolConstants {
    static let errorViewIdentifier: String = "ErrorViewIdentifier"
}
