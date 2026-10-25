import Foundation

public enum KeystoreTag: String, CaseIterable {
    case pincode

    public static func secretKeyTagForAddress(_ address: String) -> String { address + "-" +
        "secretKey"
    }

    public static func entropyTagForAddress(_ address: String) -> String { address + "-" +
        "entropy"
    }

    public static func deriviationTagForAddress(_ address: String) -> String { address + "-" +
        "deriv"
    }

    public static func seedTagForAddress(_ address: String) -> String { address + "-" + "seed" }
}

public enum KeystoreTagV2: String, CaseIterable {
    case pincode

    public static func substrateSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateSecretKey")
    }

    public static func ethereumSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-ethereumSecretKey")
    }

    public static func entropyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-entropy")
    }

    public static func substrateDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateDeriv")
    }

    public static func ethereumDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-ethereumDeriv")
    }

    public static func substrateSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: "-substrateSeed")
    }

    public static func ethereumSeedTagForMetaId(
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
