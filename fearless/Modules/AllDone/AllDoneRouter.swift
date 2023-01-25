import Foundation

final class AllDoneRouter: AllDoneRouterInput {
    func presentSubscan(from view: ControllerBackedProtocol?, url: URL) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .modal)
        view?.controller.present(webController, animated: true, completion: nil)
    }
}
