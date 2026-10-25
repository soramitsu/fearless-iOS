import Foundation
import UIKit

struct AboutViewModel {
    enum Action {
        case website(URL)
        case email
        case fontLicenses
    }

    let title: String
    let subtitle: String?
    let icon: UIImage?
    let action: Action
}
