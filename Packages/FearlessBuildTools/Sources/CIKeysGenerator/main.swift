import CIKeysGeneratorCore
import Foundation

private func writeError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let arguments = CommandLine.arguments

guard arguments.count == 3 else {
    writeError("Usage: ci-keys-generator <template-path> <output-path>")
    exit(64)
}

let templatePath = arguments[1]
let outputPath = arguments[2]

do {
    let template = try String(contentsOfFile: templatePath, encoding: .utf8)
    let output = try CIKeysGenerator.render(
        template: template,
        environment: ProcessInfo.processInfo.environment
    )

    let outputURL = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try output.write(to: outputURL, atomically: true, encoding: .utf8)

    print("Generated \(outputPath)")
} catch {
    writeError("Failed to generate CI keys: \(error)")
    exit(1)
}
