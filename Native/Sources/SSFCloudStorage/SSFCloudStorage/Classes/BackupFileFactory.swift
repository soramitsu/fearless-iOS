import Foundation

public protocol BackupFileFactoryProtocol {
    func createFile(from account: OpenBackupAccount, password: String) throws -> URL
}

public class BackupFileFactory: NSObject, BackupFileFactoryProtocol {
    private let service: EncryptionServiceProtocol

    init(service: EncryptionServiceProtocol) {
        self.service = service
    }

    public func createFile(from account: OpenBackupAccount, password: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(account.address)")
            .appendingPathExtension("json")

        let encodedPassphrase = try service.createEncryptedData(
            with: password,
            message: account.passphrase
        )
        let encodedSubstrateDerivationPath = try service.createEncryptedData(
            with: password,
            message: account.substrateDerivationPath
        )
        let encodedEthDerivationPath = try service.createEncryptedData(
            with: password,
            message: account.ethDerivationPath
        )
        let encodedSubstrateSeed = try service.createEncryptedData(
            with: password,
            message: account.encryptedSeed?.substrateSeed
        )
        let encodedEthSeed = try service.createEncryptedData(
            with: password,
            message: account.encryptedSeed?.ethSeed
        )

        let encryptedSeed = OpenBackupAccount.Seed(
            substrateSeed: encodedSubstrateSeed?.toHex(),
            ethSeed: encodedEthSeed?.toHex()
        )

        let ecryptedBackupAccount = EcryptedBackupAccount(
            name: account.name ?? "",
            address: account.address,
            encryptedMnemonicPhrase: encodedPassphrase?.toHex(),
            encryptedSubstrateDerivationPath: encodedSubstrateDerivationPath?.toHex(),
            encryptedEthDerivationPath: encodedEthDerivationPath?.toHex(),
            cryptoType: account.cryptoType,
            backupAccountType: account.backupAccountType.map { $0.map { $0.rawValue }},
            json: account.json,
            encryptedSeed: encryptedSeed
        )

        let data = try JSONEncoder().encode(ecryptedBackupAccount)
        try data.write(to: url)

        return url
    }
}
