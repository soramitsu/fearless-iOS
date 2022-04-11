import Foundation

enum JsonExportAction {
    case file
    case text

    func localizableTitle(for locale: Locale) -> String {
        switch self {
        case .file:
            return R.string.localizable.jsonExportFileTitle(preferredLanguages: locale.rLanguages)
        case .text:
            return R.string.localizable.jsonExportTextTitle(preferredLanguages: locale.rLanguages)
        }
    }
}
