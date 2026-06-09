import Foundation
import XCTest

final class GoogleKeysInjectionTests: XCTestCase {
    func testInjectGoogleKeys_whenBothSecretSetsExist_thenSelectsByConfiguration() throws {
        try assertInjectedGoogleKeys(
            configuration: "Release",
            expectedClientId: "release-client-id",
            expectedUrlScheme: "release-url-scheme"
        )
        try assertInjectedGoogleKeys(
            configuration: "Debug",
            expectedClientId: "debug-client-id",
            expectedUrlScheme: "debug-url-scheme"
        )
        try assertInjectedGoogleKeys(
            configuration: "Dev",
            expectedClientId: "debug-client-id",
            expectedUrlScheme: "debug-url-scheme"
        )
    }

    private func assertInjectedGoogleKeys(
        configuration: String,
        expectedClientId: String,
        expectedUrlScheme: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let plistURL = try makeTemporaryPlist()
        let result = runInjector(configuration: configuration, plistURL: plistURL)

        XCTAssertEqual(result.status, 0, result.output, file: file, line: line)

        let plist = try readPlist(at: plistURL)
        XCTAssertEqual(plist["GIDClientID"] as? String, expectedClientId, file: file, line: line)

        let urlTypes = try XCTUnwrap(
            plist["CFBundleURLTypes"] as? [[String: Any]],
            file: file,
            line: line
        )
        let schemes = try XCTUnwrap(
            urlTypes.first?["CFBundleURLSchemes"] as? [String],
            file: file,
            line: line
        )
        XCTAssertEqual(schemes.first, expectedUrlScheme, file: file, line: line)
    }

    private func makeTemporaryPlist() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "GIDClientID": "",
            "CFBundleURLTypes": [
                [
                    "CFBundleTypeRole": "Editor",
                    "CFBundleURLSchemes": [""]
                ]
            ]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let url = directory.appendingPathComponent("Info.plist")
        try data.write(to: url)
        return url
    }

    private func readPlist(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
    }

    private func runInjector(configuration: String, plistURL: URL) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [repoRoot.appendingPathComponent("scripts/secrets/inject-google-keys.sh").path, plistURL.path]
        process.environment = [
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin",
            "CONFIGURATION": configuration,
            "WEB_CLIENT_ID_DEBUG": "debug-client-id",
            "FEARLESS_GOOGLE_URL_SCHEME_DEBUG": "debug-url-scheme",
            "WEB_CLIENT_ID_RELEASE": "release-client-id",
            "FEARLESS_GOOGLE_URL_SCHEME_RELEASE": "release-url-scheme"
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, String(describing: error))
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
