import Foundation

enum JsonExportAction {
    case file
    case text

    var title: String {
        switch self {
        case .file:
            return R.string.localizable.jsonExportFileTitle(preferredLanguages: nil)
        case .text:
            return R.string.localizable.jsonExportTextTitle(preferredLanguages: nil)
        }
    }
}
