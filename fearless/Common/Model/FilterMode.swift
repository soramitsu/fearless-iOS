import Foundation

enum FilterMode: Int, CaseIterable {
    case disabled = 0
    case forbidSelected
    case allowSelected

    var code: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .forbidSelected:
            return "ForbidSelected"
        case .allowSelected:
            return "AllowSelected"
        }
    }
}
