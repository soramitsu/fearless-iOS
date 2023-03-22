import Foundation
import UIKit

public enum WalletViewMode {
    case view
    case edit
    case selection

    var insets: UIEdgeInsets {
        switch self {
        case .view, .selection: return UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        case .edit: return UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
    }
}
