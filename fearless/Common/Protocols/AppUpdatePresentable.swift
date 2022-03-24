import UIKit

protocol AppUpdatePresentable {
    func showAppstoreUpdatePage()
}

extension AppUpdatePresentable {
    func showAppstoreUpdatePage() {
        if let url = URL(string: URLConstants.appstoreLink) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
