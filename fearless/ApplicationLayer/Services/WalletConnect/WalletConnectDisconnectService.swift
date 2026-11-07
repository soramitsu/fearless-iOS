import Foundation
import SSFModels
import FearlessWalletConnect

protocol WalletConnectDisconnectService {
    /// Ends every session that granted an account of the wallet.
    func disconnect(wallet: MetaAccountModel) async throws
    /// Ends every session and every pairing: logging out removes every wallet.
    func disconnectAllSessions()
}

final class WalletConnectDisconnectServiceImpl: WalletConnectDisconnectService {
    private let walletConnectService: WalletConnectService

    init(walletConnectService: WalletConnectService = WalletConnectServiceImpl.shared) {
        self.walletConnectService = walletConnectService
    }

    // MARK: - WalletConnectDisconnectService

    func disconnect(wallet: MetaAccountModel) async throws {
        let sessions = WalletConnectWalletSessions.sessions(
            walletConnectService.getSessions(),
            grantingAccountsOf: wallet
        )
        // Every one of them ends, even when telling one dApp fails.
        var firstError: Error?
        for session in sessions {
            do {
                try await walletConnectService.disconnect(topic: session.topic)
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError = firstError {
            throw firstError
        }
    }

    func disconnectAllSessions() {
        let walletConnectService = self.walletConnectService
        Task {
            do {
                try await walletConnectService.disconnectAll()
            } catch {
                Logger.shared.error("WalletConnect could not end every session on logout: \(error)")
            }
        }
    }
}

/// Which sessions a wallet's accounts take part in. A session is matched by the accounts it granted, in every
/// namespace and on every chain, compared by account id: a Substrate account matches whatever address prefix the
/// session wrote it with.
enum WalletConnectWalletSessions {
    static func sessions(_ sessions: [Session], grantingAccountsOf wallet: MetaAccountModel) -> [Session] {
        let walletAccountIds = accountIds(of: wallet)
        guard !walletAccountIds.isEmpty else {
            return []
        }
        return sessions.filter { session in
            !grantedAccountIds(of: session).isDisjoint(with: walletAccountIds)
        }
    }

    /// The wallet's Substrate and EVM accounts and each of its chain accounts.
    static func accountIds(of wallet: MetaAccountModel) -> Set<AccountId> {
        var accountIds = Set(wallet.chainAccounts.map(\.accountId))
        if let substrateAccountId = wallet.substrateAccountId {
            accountIds.insert(substrateAccountId)
        }
        if let ethereumAddress = wallet.ethereumAddress {
            accountIds.insert(ethereumAddress)
        }
        return accountIds
    }

    /// The account ids a session granted: EVM addresses as their 20 bytes, SS58 addresses as their account id.
    static func grantedAccountIds(of session: Session) -> Set<AccountId> {
        Set(session.namespaces.values.flatMap(\.accounts).compactMap(accountId(of:)))
    }

    static func accountId(of account: Account) -> AccountId? {
        let address = account.address
        if account.blockchain.namespace == "eip155" || address.hasPrefix("0x") {
            guard let accountId = try? AccountId(hexStringSSF: address), accountId.count == 20 || accountId.count == 32 else {
                return nil
            }
            return accountId
        }
        return try? address.toAccountIdWithTryExtractPrefix()
    }
}
