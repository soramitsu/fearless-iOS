import Foundation
import FearlessWalletConnect
import SSFModels
import SSFUtils

protocol WalletConnectRequestPreparing {
    func prepare(
        request: Request,
        session: Session,
        wallets: [MetaAccountModel],
        chains: [ChainModel]
    ) async throws -> WalletConnectSigningRequest
}

/// Decodes a dApp request and checks it before its confirmation opens: the network, the
/// account the session approved, and, per method, what exactly would be signed.
final class WalletConnectRequestPreparer: WalletConnectRequestPreparing {
    private let modelFactory: WalletConnectModelFactory
    private let ethereumPreparer: WalletConnectEthereumRequestPreparing
    private let polkadotPreparer: WalletConnectPolkadotRequestPreparing

    init(
        modelFactory: WalletConnectModelFactory = WalletConnectModelFactoryImpl(),
        ethereumPreparer: WalletConnectEthereumRequestPreparing = WalletConnectEthereumRequestPreparer(),
        polkadotPreparer: WalletConnectPolkadotRequestPreparing = WalletConnectPolkadotRequestPreparer()
    ) {
        self.modelFactory = modelFactory
        self.ethereumPreparer = ethereumPreparer
        self.polkadotPreparer = polkadotPreparer
    }

    func prepare(
        request: Request,
        session: Session,
        wallets: [MetaAccountModel],
        chains: [ChainModel]
    ) async throws -> WalletConnectSigningRequest {
        guard request.topic == session.topic else {
            throw WalletConnectRequestError.accountNotApproved
        }

        guard let method = WalletConnectMethod(rawValue: request.method) else {
            throw WalletConnectRequestError.unsupported
        }

        guard
            let chain = try? modelFactory.resolveChain(for: request.chainId, chains: chains),
            chain.chainBaseType == method.chainBaseType
        else {
            throw WalletConnectRequestError.networkMismatch
        }

        guard let params = try? request.params.get(JSON.self) else {
            throw WalletConnectRequestError.unsupported
        }

        let binding = try WalletConnectAccountBinding.resolve(
            address: Self.requestedAddress(in: params, method: method),
            blockchain: request.chainId,
            session: session,
            wallets: wallets,
            chain: chain
        )

        let content: WalletConnectSigningRequest.Content
        switch method {
        case .polkadotSignTransaction:
            content = .polkadotTransaction(
                try await polkadotPreparer.prepareTransaction(
                    params: request.params,
                    chain: chain,
                    account: binding.account
                )
            )
        case .polkadotSignMessage:
            content = .polkadotMessage(try Self.message(params.message))
        case .ethereumSignTransaction, .ethereumSendTransaction:
            content = .ethereumTransaction(
                try await ethereumPreparer.prepareTransaction(
                    params: request.params,
                    chain: chain,
                    account: binding.account
                )
            )
        case .ethereumPersonalSign:
            content = .ethereumMessage(try Self.message(params[0]))
        case .ethereumSignTypeData, .ethereumSignTypeDataV4:
            content = .ethereumTypedData(try ethereumPreparer.prepareTypedData(params: request.params, chain: chain))
        }

        return WalletConnectSigningRequest(
            request: request,
            method: method,
            chain: chain,
            wallet: binding.wallet,
            account: binding.account,
            content: content,
            preview: request.params.stringRepresentation,
            rawDetails: params
        )
    }

    // MARK: - Private methods

    /// The account each method asks to sign with.
    private static func requestedAddress(in params: JSON, method: WalletConnectMethod) throws -> String {
        let address: String?
        switch method {
        case .polkadotSignTransaction, .polkadotSignMessage:
            address = params.address?.stringValue
        case .ethereumSignTransaction, .ethereumSendTransaction:
            address = params[0]?.from?.stringValue
        case .ethereumPersonalSign:
            address = params[1]?.stringValue
        case .ethereumSignTypeData, .ethereumSignTypeDataV4:
            address = params[0]?.stringValue
        }

        guard let address = address else {
            throw WalletConnectRequestError.unsupported
        }
        return address
    }

    private static func message(_ json: JSON?) throws -> WalletConnectMessage {
        guard let parameter = json?.stringValue, let message = try? WalletConnectMessage(parameter: parameter) else {
            throw WalletConnectRequestError.unsupported
        }
        return message
    }
}

/// Binds a request to an account the session approved for the request's chain. The
/// signing key is the one of the wallet that owns that account, never a key chosen from
/// all wallets by address alone.
enum WalletConnectAccountBinding {
    static func resolve(
        address: String,
        blockchain: Blockchain,
        session: Session,
        wallets: [MetaAccountModel],
        chain: ChainModel
    ) throws -> (wallet: MetaAccountModel, account: ChainAccountResponse) {
        let requestedAccountId = try accountId(of: address, chain: chain)

        let approvedAccountIds = session.namespaces.values
            .flatMap(\.accounts)
            .filter { $0.blockchain == blockchain }
            .compactMap { try? accountId(of: $0.address, chain: chain) }

        guard approvedAccountIds.contains(requestedAccountId) else {
            throw WalletConnectRequestError.accountNotApproved
        }

        let accountRequest = chain.accountRequest()
        for wallet in wallets {
            if let account = wallet.fetch(for: accountRequest), account.accountId == requestedAccountId {
                return (wallet, account)
            }
        }

        throw WalletConnectRequestError.accountNotApproved
    }

    static func accountId(of address: String, chain: ChainModel) throws -> AccountId {
        let accountId: AccountId?
        if chain.isEthereumBased {
            accountId = try? AccountId(hexStringSSF: address)
        } else {
            accountId = try? address.toAccountIdWithTryExtractPrefix()
        }

        guard let accountId = accountId, accountId.count == chain.accountIdLenght else {
            throw WalletConnectRequestError.accountNotApproved
        }
        return accountId
    }
}

extension WalletConnectMethod {
    var chainBaseType: ChainBaseType {
        switch self {
        case .polkadotSignTransaction, .polkadotSignMessage:
            return .substrate
        case .ethereumSignTransaction, .ethereumSendTransaction, .ethereumPersonalSign,
             .ethereumSignTypeData, .ethereumSignTypeDataV4:
            return .ethereum
        }
    }
}
