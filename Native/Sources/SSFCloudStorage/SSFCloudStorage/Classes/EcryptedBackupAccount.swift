import Foundation
import SSFUtils

public struct EcryptedBackupAccount: Codable {
    var name: String
    var address: String
    var encryptedMnemonicPhrase: String?
    var encryptedSubstrateDerivationPath: String?
    var encryptedEthDerivationPath: String?
    var cryptoType: String?
    var backupAccountType: [String]?
    var json: OpenBackupAccount.Json?
    var encryptedSeed: OpenBackupAccount.Seed?
}
