import UIKit
import SoraUI

struct ApplicationStatusStyle {
    let backgroundColor: UIColor
    let titleColor: UIColor
    let titleFont: UIFont
}

protocol ApplicationStatusPresentable: AnyObject {
    func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool)
    func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool)
}
