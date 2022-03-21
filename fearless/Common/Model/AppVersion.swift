import Foundation

struct AppVersion {
    static let stringValue = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
}
