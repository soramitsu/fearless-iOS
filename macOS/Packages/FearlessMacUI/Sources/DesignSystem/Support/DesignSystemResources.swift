import AppKit
import Foundation

/// Access to the files bundled with the design system (fonts, chain and
/// token icons, brand marks). SwiftPM copies the three folders as they are.
public enum DesignSystemResources {
    public static var bundle: Bundle { Bundle.module }

    public static func url(forResource name: String, withExtension ext: String, subdirectory: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    /// Every file with `ext` in a bundled folder, keyed by lowercased stem.
    static func index(of subdirectory: String, withExtension ext: String) -> [String: URL] {
        let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) ?? []
        var result: [String: URL] = [:]
        for url in urls {
            result[url.deletingPathExtension().lastPathComponent.lowercased()] = url
        }
        return result
    }
}
