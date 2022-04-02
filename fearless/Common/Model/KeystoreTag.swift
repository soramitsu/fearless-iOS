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
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateSecretKey")
    }

    static func ethereumSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-ethereumSecretKey")
    }

    static func entropyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-entropy")
    }

    static func substrateDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateDeriv")
    }

    static func ethereumDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-ethereumDeriv")
    }

    static func substrateSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateSeed")
    }

    static func ethereumSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-ethereumSeed")
    }

    private static func createTagForMetaId(
        _ metaId: String,
        accountId: AccountId?,
        suffix: String
    ) -> String {
        accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }
}
