import Foundation

@testable import SSFCloudStorage

final class BackupFileFactoryMock: BackupFileFactoryProtocol {
    // MARK: - createFile

    var createFileCallsCount: Int = 0
    var createFileCalled: Bool {
        createFileCallsCount > 0
    }

    var createFileReceivedArguments: (account: OpenBackupAccount, password: String)?
    var createFileReceivedInvocations: [(account: OpenBackupAccount, password: String)] = []
    var createFileReturnValue: URL!

    func createFile(from account: OpenBackupAccount, password: String) throws -> URL {
        createFileCallsCount += 1
        createFileReceivedArguments = (account: account, password: password)
        createFileReceivedInvocations.append((account: account, password: password))
        return createFileReturnValue
    }
}
