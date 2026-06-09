import Foundation
import XCTest

final class RuntimeKeysValidationTests: XCTestCase {
    func testValidateRuntimeKeys_whenStrictAndAllValuesProvided_thenPasses() throws {
        let envURL = try makeEnvironmentFile()

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] OK"))
    }

    func testValidateRuntimeKeys_whenStrictAndPlaceholderProvided_thenFails() throws {
        let envURL = try makeEnvironmentFile(overrides: ["MOONPAY_PRODUCTION_SECRET": "CHANGE_ME"])

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Placeholder 1 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("MOONPAY_PRODUCTION_SECRET"), result.output)
    }

    func testValidateRuntimeKeys_whenStrictAndWhitespaceProvided_thenFailsAsMissing() throws {
        let envURL = try makeEnvironmentFile(overrides: ["MOONPAY_PRODUCTION_SECRET": "   "])

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Missing 1 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("MOONPAY_PRODUCTION_SECRET"), result.output)
    }

    func testValidateRuntimeKeys_whenStrictAndExampleUrlProvided_thenFailsAsPlaceholder() throws {
        let envURL = try makeEnvironmentFile(overrides: ["SORA_CARD_KYC_ENDPOINT_URL": "https://example.com/kyc"])

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Placeholder 1 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("SORA_CARD_KYC_ENDPOINT_URL"), result.output)
    }

    func testValidateRuntimeKeys_whenFallbackBackedDebugValueMissing_thenUsesReleaseValue() throws {
        let envURL = try makeEnvironmentFile(omitting: ["FL_WALLET_CONNECT_PROJECT_ID_DEBUG"])

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] OK"), result.output)
    }

    func testValidateRuntimeKeys_whenFallbackBackedDebugValueIsWhitespace_thenUsesReleaseValue() throws {
        let envURL = try makeEnvironmentFile(overrides: ["FL_WALLET_CONNECT_PROJECT_ID_DEBUG": "   "])

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] OK"), result.output)
    }

    func testValidateRuntimeKeys_whenGoogleAndTonDebugValuesMissing_thenUseReleaseValues() throws {
        let envURL = try makeEnvironmentFile(
            omitting: [
                "WEB_CLIENT_ID_DEBUG",
                "FEARLESS_GOOGLE_URL_SCHEME_DEBUG",
                "FL_TON_API_KEY_DEBUG"
            ]
        )

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] OK"), result.output)
    }

    func testValidateRuntimeKeys_whenFallbackBackedValuesAndSourcesMissing_thenReportsOnlySources() throws {
        let envURL = try makeEnvironmentFile(omitting: try Set(runtimeKeys()))

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Missing 33 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("FL_WALLET_CONNECT_PROJECT_ID"), result.output)
        XCTAssertFalse(result.output.contains("FL_WALLET_CONNECT_PROJECT_ID_DEBUG"), result.output)
        XCTAssertTrue(result.output.contains("WEB_CLIENT_ID_RELEASE"), result.output)
        XCTAssertFalse(result.output.contains("WEB_CLIENT_ID_DEBUG"), result.output)
        XCTAssertTrue(result.output.contains("FL_TON_API_KEY"), result.output)
        XCTAssertFalse(result.output.contains("FL_TON_API_KEY_DEBUG"), result.output)
    }

    func testValidateRuntimeKeys_whenFallbackBackedDebugValueMissingAndReleaseValuePlaceholder_thenFails() throws {
        let envURL = try makeEnvironmentFile(
            overrides: ["FL_WALLET_CONNECT_PROJECT_ID": "PLACEHOLDER"],
            omitting: ["FL_WALLET_CONNECT_PROJECT_ID_DEBUG"]
        )

        let result = runValidator(envURL: envURL, strict: true)

        XCTAssertNotEqual(result.status, 0, result.output)
        XCTAssertFalse(result.output.contains("[runtime-keys] Missing"), result.output)
        XCTAssertFalse(result.output.contains("FL_WALLET_CONNECT_PROJECT_ID_DEBUG"), result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Placeholder 1 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("FL_WALLET_CONNECT_PROJECT_ID"), result.output)
    }

    func testValidateRuntimeKeys_whenNonStrictAndPlaceholderProvided_thenWarnsWithoutFailing() throws {
        let envURL = try makeEnvironmentFile(overrides: ["MOONPAY_PRODUCTION_SECRET": "<secret>"])

        let result = runValidator(envURL: envURL, strict: false)

        XCTAssertEqual(result.status, 0, result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] Placeholder 1 key(s):"), result.output)
        XCTAssertTrue(result.output.contains("[runtime-keys] WARN"), result.output)
    }

    private func makeEnvironmentFile(
        overrides: [String: String] = [:],
        omitting omittedKeys: Set<String> = []
    ) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let envURL = directory.appendingPathComponent(".env")
        let keys = try runtimeKeys()
        let contents = keys
            .filter { !omittedKeys.contains($0) }
            .map { key in "\(key)=\(shellQuoted(overrides[key] ?? "value_\(key)"))" }
            .joined(separator: "\n")

        try contents.write(to: envURL, atomically: true, encoding: .utf8)
        return envURL
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func runtimeKeys() throws -> [String] {
        let envExample = try String(contentsOf: repoRoot.appendingPathComponent(".env.example"), encoding: .utf8)

        return envExample
            .split(separator: "\n")
            .compactMap { line -> String? in
                guard let separatorIndex = line.firstIndex(of: "=") else {
                    return nil
                }

                let key = line[..<separatorIndex]
                return key.isEmpty || key.hasPrefix("#") ? nil : String(key)
            }
    }

    private func runValidator(envURL: URL, strict: Bool) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            repoRoot.appendingPathComponent("scripts/secrets/validate-runtime-keys.sh").path,
            repoRoot.path
        ]
        process.environment = [
            "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin",
            "ENV_FILE": envURL.path,
            "STRICT_RUNTIME_KEYS": strict ? "1" : "0"
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
