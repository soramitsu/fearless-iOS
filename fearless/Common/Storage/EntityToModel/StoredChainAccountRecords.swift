import CoreData
import Foundation
import SSFModels

/// Why a stored per-chain account row cannot be used. The row is always kept.
enum StoredChainAccountIssue: String, Equatable, CaseIterable {
    case unreadable
    case missingField
    case invalidChainId
    case invalidCryptoType
    case invalidAccountId
    case invalidPublicKey
    /// A second account for a network whose account the app derives itself
    /// (Bitcoin, Solana, TON, Taira). Only one of them can be used there.
    case duplicateDerivedAccount
}

struct UnusableStoredChainAccount: Equatable {
    let chainId: String?
    let issue: StoredChainAccountIssue
}

/// The per-chain account rows of one stored wallet, sorted by what the app does with them.
struct StoredChainAccountRecords: Equatable {
    static let empty = StoredChainAccountRecords(active: [], alternatives: [], unusable: [])

    /// The account in use for its chain. At most one per chain.
    let active: [ChainAccountModel]
    /// Valid accounts that stay stored but are not in use for their chain. The user can
    /// switch to any of them, and switching never deletes the one it replaces.
    let alternatives: [ChainAccountModel]
    /// Rows that failed validation. They are skipped, never rewritten and never deleted.
    let unusable: [UnusableStoredChainAccount]

    /// The wallet with its per-chain accounts as an ordinary save stores them: an account
    /// the model still carries but the store keeps as an alternative gives way to the
    /// account in use on that chain (or to the wallet's own account when none is), and an
    /// account in use on a chain the model does not carry stays in use, because an ordinary
    /// save never removes a row. A copy of the wallet from before an explicit switch
    /// therefore comes back with the account chosen since.
    func keepingAccountsInUse(in wallet: MetaAccountModel) -> MetaAccountModel {
        var accounts = Set<ChainAccountModel>()
        for account in wallet.chainAccounts {
            let chainId = UniversalWalletChainAccountSupport.canonicalChainId(for: account.chainId)
            let onSameChain: (ChainAccountModel) -> Bool = {
                UniversalWalletChainAccountSupport.canonicalChainId(for: $0.chainId) == chainId
            }
            let isStoredAlternative = alternatives.contains {
                onSameChain($0) && $0.accountId == account.accountId &&
                    $0.publicKey == account.publicKey && $0.cryptoType == account.cryptoType
            }

            guard isStoredAlternative else {
                accounts.insert(account)
                continue
            }
            if let inUse = active.first(where: onSameChain) {
                accounts.insert(inUse)
            }
        }

        let carriedChainIds = Set(accounts.map {
            UniversalWalletChainAccountSupport.canonicalChainId(for: $0.chainId)
        })
        for inUse in active where !carriedChainIds.contains(
            UniversalWalletChainAccountSupport.canonicalChainId(for: inUse.chainId)
        ) {
            accounts.insert(inUse)
        }

        guard accounts != wallet.chainAccounts else {
            return wallet
        }

        return wallet.replacingChainAccounts(accounts)
    }
}

/// What a wallet uses on one chain: its own root account or one of its stored per-chain accounts.
enum ChainAccountSelection: Equatable {
    case walletAccount
    case chainAccount(accountId: AccountId, publicKey: Data)
}

struct ChainAccountSelectionUpdate: Equatable {
    let chainId: ChainModel.Id
    let selection: ChainAccountSelection
}

enum ChainAccountSelectionError: LocalizedError, Equatable {
    case unsupportedChain
    case accountNotStored
    case walletAccountUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedChain:
            return "The account of this network cannot be switched"
        case .accountNotStored:
            return "The selected account is not stored for this network"
        case .walletAccountUnavailable:
            return "The wallet has no account of its own for this network"
        }
    }
}

struct StoredChainAccountRow {
    let entity: NSManagedObject
    let account: ChainAccountModel
    let canonicalChainId: String
    /// False only for a row in the shape the 4.0.x releases left hidden: its `ecosystem`
    /// and its `ethereumBased` are both absent.
    let isLabelled: Bool
}

struct StoredChainAccountClassification {
    var active: [StoredChainAccountRow] = []
    var alternatives: [StoredChainAccountRow] = []
    var unusable: [UnusableStoredChainAccount] = []

    var records: StoredChainAccountRecords {
        StoredChainAccountRecords(
            active: active.map(\.account),
            alternatives: alternatives.map(\.account),
            unusable: unusable
        )
    }

    func activeRow(forCanonicalChainId canonicalChainId: String) -> StoredChainAccountRow? {
        active.first { $0.canonicalChainId == canonicalChainId }
    }

    func alternativeRows(forCanonicalChainId canonicalChainId: String) -> [StoredChainAccountRow] {
        alternatives.filter { $0.canonicalChainId == canonicalChainId }
    }
}

/// Decides, row by row, which stored per-chain accounts a wallet uses.
///
/// A row that fails validation is skipped on its own, so it can neither hide the wallet
/// nor block saving it.
///
/// The 4.0.x releases dropped `ethereumBased`, added `ecosystem` as nil on every row that
/// existed, and showed only rows with a known `ecosystem`. A per-chain account from an
/// earlier release therefore stayed stored but hidden, and the wallet's own account was
/// shown for that chain. Such a row has neither field. It is kept as an alternative while
/// the wallet has an account of its own for that chain, so the address the user saw in
/// 4.0.x stays the one in use. A row that carries either field was shown by the release
/// that wrote it and stays in use.
///
/// Releases 2.0.0 to 2.0.8 also wrote rows without `ethereumBased`, and 2.0.9 to 3.7.4
/// added it only when they saved that wallet again; those releases used such a row. A
/// store that never ran 4.0.x is labelled the way they read it when it is migrated
/// (`UserStorageMigrator.labelPreEcosystemChainAccounts`), so only rows 4.0.x actually
/// hid reach this rule.
///
/// Accounts for the networks the app derives itself (`isUniversalWalletChain`) were
/// first written by the 4.2 line, always labelled, and cannot be switched. A second row
/// for such a network is reported as unusable instead of being offered.
enum StoredChainAccountClassifier {
    private static let ethereumEcosystems: Set<String> = [
        UniversalWalletEcosystem.evm.rawValue,
        "ethereum",
        "ethereumBased"
    ]

    static func classify(chainAccountsOf wallet: NSManagedObject) -> StoredChainAccountClassification {
        var classification = StoredChainAccountClassification()
        var rowsByChain: [String: [StoredChainAccountRow]] = [:]
        var chainOrder: [String] = []

        let entities = (wallet.value(forKey: "chainAccounts") as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        for entity in entities {
            switch read(entity) {
            case let .success(row):
                if rowsByChain[row.canonicalChainId] == nil {
                    chainOrder.append(row.canonicalChainId)
                }
                rowsByChain[row.canonicalChainId, default: []].append(row)
            case let .failure(unusable):
                classification.unusable.append(unusable.row)
            }
        }

        for canonicalChainId in chainOrder.sorted() {
            // `chainAccounts` is an unordered relationship. Sorting keeps the choice
            // between several rows of one chain independent of fetch order.
            let rows = (rowsByChain[canonicalChainId] ?? []).sorted(by: precedes)
            let labelled = rows.filter(\.isLabelled)
            let unlabelled = rows.filter { !$0.isLabelled }

            if let inUse = rows.first,
               UniversalWalletChainAccountSupport.isUniversalWalletChain(inUse.account.chainId) {
                classification.active.append(inUse)
                classification.unusable.append(contentsOf: rows.dropFirst().map {
                    UnusableStoredChainAccount(chainId: $0.account.chainId, issue: .duplicateDerivedAccount)
                })
            } else if let inUse = labelled.first {
                classification.active.append(inUse)
                classification.alternatives.append(contentsOf: labelled.dropFirst())
                classification.alternatives.append(contentsOf: unlabelled)
            } else if let candidate = unlabelled.first {
                if walletAccountExists(in: wallet, ethereumBased: candidate.account.ethereumBased) {
                    classification.alternatives.append(contentsOf: unlabelled)
                } else {
                    // The 4.0.x releases showed no account for this chain, so there is no
                    // address to keep and hiding the row would strand the only account.
                    classification.active.append(candidate)
                    classification.alternatives.append(contentsOf: unlabelled.dropFirst())
                }
            }
        }

        classification.unusable.sort { ($0.chainId ?? "", $0.issue.rawValue) < ($1.chainId ?? "", $1.issue.rawValue) }

        return classification
    }

    static func walletAccountExists(in wallet: NSManagedObject, ethereumBased: Bool) -> Bool {
        if ethereumBased {
            return wallet.value(forKey: "ethereumAddress") != nil &&
                wallet.value(forKey: "ethereumPublicKey") != nil
        }

        return wallet.value(forKey: "substrateAccountId") != nil &&
            wallet.value(forKey: "substratePublicKey") != nil
    }

    static func ecosystem(for account: ChainAccountModel) -> String {
        account.ethereumBased
            ? UniversalWalletEcosystem.evm.rawValue
            : UniversalWalletEcosystem.substrate.rawValue
    }

    /// A 20-byte account with an ECDSA key is an Ethereum address whatever the row says.
    /// A Substrate account identifier is always 32 bytes long.
    static func isStructurallyEthereumBased(accountId: AccountId, cryptoType: CryptoType) -> Bool {
        accountId.count == 20 && cryptoType == .ecdsa
    }

    private struct UnusableRow: Error {
        let row: UnusableStoredChainAccount
    }

    private static func read(_ entity: NSManagedObject) -> Result<StoredChainAccountRow, UnusableRow> {
        var result: Result<StoredChainAccountRow, UnusableRow>?

        // A generated Core Data getter may raise NSException for a damaged row. Give every
        // row its own boundary, so one row that cannot materialize costs only that row.
        try? SafeObjectiveCExceptionBoundary.perform {
            result = readWithoutExceptionBoundary(entity)
        }

        return result ?? .failure(UnusableRow(row: UnusableStoredChainAccount(chainId: nil, issue: .unreadable)))
    }

    // One validation per stored field, in the order the row is checked.
    // swiftlint:disable:next function_body_length
    private static func readWithoutExceptionBoundary(
        _ entity: NSManagedObject
    ) -> Result<StoredChainAccountRow, UnusableRow> {
        let storedChainId = entity.value(forKey: "chainId") as? String

        func unusable(_ issue: StoredChainAccountIssue) -> Result<StoredChainAccountRow, UnusableRow> {
            .failure(UnusableRow(row: UnusableStoredChainAccount(chainId: storedChainId, issue: issue)))
        }

        guard
            let chainId = storedChainId,
            let accountIdHex = entity.value(forKey: "accountId") as? String,
            let publicKey = entity.value(forKey: "publicKey") as? Data
        else {
            return unusable(.missingField)
        }

        guard !chainId.isEmpty, chainId == chainId.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return unusable(.invalidChainId)
        }

        let storedCryptoType = (entity.value(forKey: "cryptoType") as? NSNumber)?.int16Value ?? 0
        guard
            let cryptoType = CryptoType(rawValue: UInt8(truncatingIfNeeded: storedCryptoType)),
            Int16(cryptoType.rawValue) == storedCryptoType
        else {
            return unusable(.invalidCryptoType)
        }

        guard let accountId = try? Data(hexStringSSF: accountIdHex), !accountId.isEmpty else {
            return unusable(.invalidAccountId)
        }

        guard publicKey.count == (cryptoType == .ecdsa ? 33 : 32) else {
            return unusable(.invalidPublicKey)
        }

        let properties = entity.entity.propertiesByName
        let hasEcosystem = properties["ecosystem"] != nil
        let storedEcosystem = hasEcosystem ? entity.value(forKey: "ecosystem") as? String : nil
        let storedEthereumBased = properties["ethereumBased"] != nil
            ? entity.value(forKey: "ethereumBased") as? NSNumber
            : nil

        let isEthereumBased =
            storedEcosystem.map(ethereumEcosystems.contains) == true ||
            storedEthereumBased?.boolValue == true ||
            isStructurallyEthereumBased(accountId: accountId, cryptoType: cryptoType)

        // Universal-wallet accounts were first written by the 4.2 line, always with a label.
        let isLabelled =
            !hasEcosystem ||
            storedEcosystem != nil ||
            storedEthereumBased != nil ||
            UniversalWalletChainAccountSupport.isUniversalWalletChain(chainId)

        return .success(
            StoredChainAccountRow(
                entity: entity,
                account: ChainAccountModel(
                    chainId: chainId,
                    accountId: accountId,
                    publicKey: publicKey,
                    cryptoType: cryptoType.rawValue,
                    ethereumBased: isEthereumBased
                ),
                canonicalChainId: UniversalWalletChainAccountSupport.canonicalChainId(for: chainId),
                isLabelled: isLabelled
            )
        )
    }

    private static func precedes(_ lhs: StoredChainAccountRow, _ rhs: StoredChainAccountRow) -> Bool {
        let lhsKey = (lhs.account.accountId.toHex(), lhs.account.publicKey.toHex(), lhs.account.cryptoType)
        let rhsKey = (rhs.account.accountId.toHex(), rhs.account.publicKey.toHex(), rhs.account.cryptoType)

        return lhsKey < rhsKey
    }
}

extension StoredChainAccountRow {
    func hasIdentity(of account: ChainAccountModel) -> Bool {
        self.account.accountId == account.accountId &&
            self.account.publicKey == account.publicKey &&
            self.account.cryptoType == account.cryptoType
    }

    /// Marks the row as the account in use for its chain. Only the two label fields change.
    func label() {
        let properties = entity.entity.propertiesByName
        if properties["ethereumBased"] != nil {
            entity.setValue(account.ethereumBased, forKey: "ethereumBased")
        }
        if properties["ecosystem"] != nil {
            entity.setValue(StoredChainAccountClassifier.ecosystem(for: account), forKey: "ecosystem")
        }
    }

    /// Returns the row to the stored-but-not-in-use shape. The account, its key and its
    /// chain stay as they are.
    func removeLabel() {
        let properties = entity.entity.propertiesByName
        guard properties["ecosystem"] != nil else {
            return
        }
        entity.setValue(nil, forKey: "ecosystem")
        if properties["ethereumBased"] != nil {
            entity.setValue(nil, forKey: "ethereumBased")
        }
    }
}
