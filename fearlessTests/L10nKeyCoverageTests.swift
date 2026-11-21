import XCTest
@testable import fearless

/// L10n looks a key up in one language's Localizable.strings and shows the key itself when the table lacks it. Every
/// L10n member the app's sources use must therefore have its key in each Localizable.strings: the eight the app
/// ships and the repository's pt.lproj, which the target does not include.
final class L10nKeyCoverageTests: XCTestCase {
    private let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testEveryL10nKeyTheAppUsesIsInEveryShippedStringsTable() throws {
        let keysByMember = try l10nKeysByMember()
        XCTAssertGreaterThan(keysByMember.count, 90, "L10n.swift was not read as expected")

        let usedKeys = try usedMembers().compactMap { keysByMember[$0] }
        // The twelve keys used when this test was written; fewer means the source scan broke.
        XCTAssertGreaterThanOrEqual(Set(usedKeys).count, 12)

        let bundle = Bundle(for: ChainAssetListInteractor.self)
        let tables = bundle.localizations.filter {
            bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: $0) != nil
        }
        XCTAssertTrue(tables.contains("en"), "the base table ships")
        XCTAssertGreaterThanOrEqual(tables.count, 8)

        for language in tables.sorted() {
            let path = try XCTUnwrap(bundle.path(forResource: language, ofType: "lproj"))
            let table = try XCTUnwrap(Bundle(path: path))
            let missing = Set(usedKeys).filter {
                table.localizedString(forKey: $0, value: Self.missingMarker, table: nil) == Self.missingMarker
            }
            XCTAssertEqual(missing.sorted(), [], "shipped \(language).lproj/Localizable.strings lacks keys the app uses")
        }

        let sourceTables = try FileManager.default
            .contentsOfDirectory(at: repoRoot.appendingPathComponent("fearless"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" }
            .map { $0.appendingPathComponent("Localizable.strings") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertGreaterThanOrEqual(sourceTables.count, 9)
        for url in sourceTables {
            let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], url.path)
            let missing = Set(usedKeys).subtracting(table.keys)
            let language = url.deletingLastPathComponent().lastPathComponent
            XCTAssertEqual(missing.sorted(), [], "\(language)/Localizable.strings lacks keys the app uses")
        }
    }

    private static let missingMarker = "\u{1}missing\u{1}"

    /// `L10n.Common.fullName` -> `common.full_name`, read from the nested enums of L10n.swift.
    private func l10nKeysByMember() throws -> [String: String] {
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("fearless/Common/Localization/L10n.swift"),
            encoding: .utf8
        )
        var keys: [String: String] = [:]
        var enums: [(name: String, depth: Int)] = []
        var depth = 0
        var member: String?

        for line in source.components(separatedBy: .newlines) {
            if let name = firstCapture(#"^\s*(?:public |private )?enum (\w+)"#, in: line) {
                enums.append((name, depth))
            }
            if let name = firstCapture(#"public static (?:var|func) (\w+)"#, in: line) {
                member = name
            }
            if let key = firstCapture(#"localize\("([^"]+)""#, in: line), let member, let root = enums.first?.name {
                let path = ([root] + enums.dropFirst().map(\.name) + [member]).joined(separator: ".")
                keys[path] = key
            }
            depth += line.filter { $0 == "{" }.count - line.filter { $0 == "}" }.count
            while let last = enums.last, depth <= last.depth {
                enums.removeLast()
            }
        }
        return keys
    }

    /// Every `L10n.A.b` written in the app's Swift sources, L10n.swift itself excepted.
    private func usedMembers() throws -> Set<String> {
        let appRoot = repoRoot.appendingPathComponent("fearless")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil))
        let pattern = try NSRegularExpression(pattern: #"\bL10n(?:\.[A-Za-z_][A-Za-z0-9_]*)+"#)
        var members = Set<String>()
        for case let url as URL in enumerator where url.pathExtension == "swift" && url.lastPathComponent != "L10n.swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                if let found = Range(match.range, in: text) {
                    members.insert(String(text[found]))
                }
            }
        }
        return members
    }

    private func firstCapture(_ pattern: String, in line: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let range = Range(match.range(at: 1), in: line)
        else {
            return nil
        }
        return String(line[range])
    }
}
