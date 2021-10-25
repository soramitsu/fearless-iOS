import Foundation

@available(*, deprecated, message: "Use MetaAccountImportPreferredInfo instead")
struct AccountImportPreferredInfo {
    let username: String?
    let networkType: Chain?
    let cryptoType: CryptoType?
    let networkTypeConfirmed: Bool
}

// TODO: Rename after refactoring
struct MetaAccountImportPreferredInfo {
    let username: String?
    let networkType: Chain?
    let cryptoType: MultiassetCryptoType?
    let networkTypeConfirmed: Bool
}
