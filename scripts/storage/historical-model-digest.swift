import CoreData
import CryptoKit
import Darwin
import Foundation

// Prints one JSON line per compiled Core Data model:
//   {"digest", "entities", "path", "versionChecksum"}
//
// `digest` identifies a store schema the way Core Data's store metadata does: the
// first 16 hex characters of SHA-256 over the entity version hashes, sorted by
// entity name and joined as `name=base64(versionHash)` with `;`. Two models with
// the same digest open exactly the same stores, whatever their XML looks like.
// `versionChecksum` is Core Data's own checksum of the compiled model.

guard CommandLine.arguments.count > 1 else {
    fputs("usage: historical-model-digest.swift <model.mom> [...]\n", stderr)
    exit(EX_USAGE)
}

for path in CommandLine.arguments.dropFirst() {
    guard let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: path)) else {
        fputs("unable to load Core Data model: \(path)\n", stderr)
        exit(EX_DATAERR)
    }

    let hashes = model.entityVersionHashesByName
    let canonical = hashes.keys.sorted()
        .map { name in "\(name)=\(hashes[name]?.base64EncodedString() ?? "")" }
        .joined(separator: ";")
    let digest = SHA256.hash(data: Data(canonical.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
        .prefix(16)

    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let record: [String: Any] = [
        "path": path,
        "digest": String(digest),
        "versionChecksum": model.versionChecksum,
        "entities": hashes.mapValues { $0.base64EncodedString() }
    ]
    withExtendedLifetime(coordinator) {}

    guard
        let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
        let line = String(data: data, encoding: .utf8)
    else {
        fputs("unable to encode digest for: \(path)\n", stderr)
        exit(EX_SOFTWARE)
    }

    print(line)
}
