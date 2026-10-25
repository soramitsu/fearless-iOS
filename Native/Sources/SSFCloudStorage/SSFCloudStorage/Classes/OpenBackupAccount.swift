import Foundation
import SSFUtils

public struct OpenBackupAccount: Codable {
    public enum BackupAccountType: String, Codable {
        case passphrase
        case json
        case seed
    }

    public struct Json: Codable, Hashable {
        public var substrateJson: String?
        public var ethJson: String?

        public init(substrateJson: String? = nil, ethJson: String? = nil) {
            self.substrateJson = substrateJson
            self.ethJson = ethJson
        }
    }

    public struct Seed: Codable, Hashable {
        public var substrateSeed: String?
        public var ethSeed: String?

        public init(substrateSeed: String? = nil, ethSeed: String? = nil) {
            self.substrateSeed = substrateSeed
            self.ethSeed = ethSeed
        }
    }

    public var name: String?
    public var address: String
    public var cryptoType: String?
    public var substrateDerivationPath: String?
    public var ethDerivationPath: String?

    public var backupAccountType: [BackupAccountType]?

    public var passphrase: String?
    public var json: Json?
    public var encryptedSeed: Seed?

    public init(
        name: String? = nil,
        address: String,
        passphrase: String? = nil,
        cryptoType: String? = nil,
        substrateDerivationPath: String? = nil,
        ethDerivationPath: String? = nil,
        backupAccountType: [BackupAccountType]? = nil,
        json: Json? = nil,
        encryptedSeed: Seed? = nil
    ) {
        self.name = name
        self.address = address
        self.passphrase = passphrase
        self.substrateDerivationPath = substrateDerivationPath
        self.ethDerivationPath = ethDerivationPath
        self.cryptoType = cryptoType
        self.backupAccountType = backupAccountType
        self.json = json
        self.encryptedSeed = encryptedSeed
    }
}

extension OpenBackupAccount {
    static func create(
        address: String,
        password: String,
        substrateData: Data,
        ethereumData: Data
    ) throws -> OpenBackupAccount {
        let definition = try JSONDecoder().decode(KeystoreDefinition.self, from: substrateData)
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let substrateJson = String(data: substrateData, encoding: .utf8)
        let ethereumJson = String(data: ethereumData, encoding: .utf8)
        let json = OpenBackupAccount.Json(
            substrateJson: substrateJson,
            ethJson: ethereumJson
        )

        return OpenBackupAccount(
            name: info.meta?.name,
            address: address,
            passphrase: password,
            cryptoType: String(info.cryptoType.rawValue),
            backupAccountType: [.json],
            json: json
        )
    }
}
