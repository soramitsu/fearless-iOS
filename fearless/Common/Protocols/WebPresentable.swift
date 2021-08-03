import Foundation
import UIKit
import SafariServices

enum WebPresentableStyle {
    case automatic
    case modal
}

protocol WebPresentable: AnyObject {
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle)
}

extension WebPresentable {
    func showWeb(url: URL, from view: ControllerBackedProtocol, style: WebPresentableStyle) {
        let webController = WebViewFactory.createWebViewController(for: url, style: style)
        view.controller.present(webController, animated: true, completion: nil)
    }
}

enum WebViewFactory {
    static func createWebViewController(for url: URL, style: WebPresentableStyle) -> UIViewController {
        let webController = SFSafariViewController(url: url)
        webController.preferredControlTintColor = R.color.colorWhite()!
        webController.preferredBarTintColor = R.color.colorAlmostBlack()!

        switch style {
        case .modal:
            webController.modalPresentationStyle = .overFullScreen
        default:
            break
        }

        return webController
    }
}
