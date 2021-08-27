import Foundation

enum KeystoreTag: String, CaseIterable {
    case pincode

    static func secretKeyTagForAddress(_ address: String) -> String { address + "-" + "secretKey" }
    static func entropyTagForAddress(_ address: String) -> String { address + "-" + "entropy" }
    static func deriviationTagForAddress(_ address: String) -> String { address + "-" + "deriv" }
    static func seedTagForAddress(_ address: String) -> String { address + "-" + "seed" }
}

enum KeystoreTagV2: String, CaseIterable {
    case pincode

    static func substrateSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-substrateSecretKey"

        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func ethereumSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-ethereumSecretKey"

        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func entropyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-entropy"

        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func substrateDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-substrateDeriv"
        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func ethereumDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-ethereumDeriv"
        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func substrateSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-substrateSeed"
        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }

    static func ethereumSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        let suffix = "-ethereumSeed"
        return accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }
}
