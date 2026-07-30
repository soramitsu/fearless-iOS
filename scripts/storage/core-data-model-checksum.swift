import CoreData
import Darwin
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("usage: core-data-model-checksum.swift <model.mom> [...]\n", stderr)
    exit(EX_USAGE)
}

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)

    guard let model = NSManagedObjectModel(contentsOf: url) else {
        fputs("unable to load Core Data model: \(path)\n", stderr)
        exit(EX_DATAERR)
    }

    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    print(model.versionChecksum)
    withExtendedLifetime(coordinator) {}
}
