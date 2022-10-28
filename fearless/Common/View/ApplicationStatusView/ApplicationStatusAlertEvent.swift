import Foundation
import UIKit

protocol ApplicationStatusAlertEvent {
    var autoDismissing: Bool { get }
    var backgroundColor: UIColor { get }
    var image: UIImage? { get }
    var titleText: String { get }
    var descriptionText: String { get }
}
