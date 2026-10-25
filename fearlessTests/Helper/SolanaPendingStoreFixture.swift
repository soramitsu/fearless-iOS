@testable import fearless
import Foundation

// This convenience initializer exists only in the test target. Production callers must
// provide a journal explicitly; .shared always uses app-private Application Support.
extension SolanaPendingBroadcastStore {
    convenience init(userDefaults: UserDefaults, logger: LoggerProtocol? = nil) {
        self.init(userDefaults: userDefaults, logger: logger,
                  journal: SolanaPendingStoreFixture.journal(for: userDefaults))
    }
}

private enum SolanaPendingStoreFixture {
    static let lock = NSLock()
    static func journal(for defaults: UserDefaults) -> SolanaPendingBroadcastJournal {
        lock.lock(); defer { lock.unlock() }
        let key = "test.solana-pending-journal-namespace"
        let namespace = defaults.string(forKey: key) ?? UUID().uuidString
        defaults.set(namespace, forKey: key)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("solana-pending-tests-" + namespace, isDirectory: true)
        try! FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        return try! SolanaPendingBroadcastJournal(parentDirectoryURL: parent)
    }
}
