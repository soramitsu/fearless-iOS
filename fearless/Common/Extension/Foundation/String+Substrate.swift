import Foundation

extension String {
    var displayCall: String {
        replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayModule: String { capitalized }
}
