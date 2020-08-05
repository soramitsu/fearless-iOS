import UIKit

enum FieldStatus {
    case none
    case valid
    case warning
    case invalid
}

extension FieldStatus {
    var icon: UIImage? {
        switch self {
        case .valid:
            return R.image.iconValid()
        case .invalid:
            return R.image.iconInvalid()
        case .warning:
            return R.image.iconAlert()
        case .none:
            return nil
        }
    }
}
