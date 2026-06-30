import Foundation
import SSFModels
import SSFExtrinsicKit
import SSFUtils
import BigInt

protocol TransferFeeEstimationListener: AnyObject {
    func didReceiveFee(fee: BigUInt)
    func didReceiveFeeError(feeError: Error)
}

enum TransferServiceError: Error {
    case cannotEstimateFee(reason: String)
    case transferFailed(reason: String)
    case unexpected
}

struct Transfer {
    let chainAsset: ChainAsset
    let amount: BigUInt
    let receiver: String
    let tip: BigUInt?
    let appId: BigUInt?
}

protocol TransferServiceProtocol {
    func estimateFee(for transfer: Transfer) async throws -> BigUInt
    func submit(transfer: Transfer) async throws -> String
    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener)
    func unsubscribe()

    func estimateFee(for transfer: XorlessTransfer) async throws -> BigUInt
    func submit(transfer: XorlessTransfer) async throws -> String
}

extension TransferServiceProtocol {
    func estimateFee(for _: XorlessTransfer) async throws -> BigUInt { .zero }
    func submit(transfer _: XorlessTransfer) async throws -> String { "" }
}

final class BitcoinTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let planner: BitcoinSendPlanner
    private let sendService: BitcoinSendService
    private let mnemonicProvider: BitcoinMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        client: BitcoinIndexerClientProtocol = BitcoinIndexerClient(),
        mnemonicProvider: BitcoinMnemonicProviding = KeychainBitcoinMnemonicProvider()
    ) {
        self.wallet = wallet
        self.chain = chain
        planner = BitcoinSendPlanner(client: client)
        sendService = BitcoinSendService(client: client)
        self.mnemonicProvider = mnemonicProvider
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        let context = try resolveContext(failure: TransferServiceError.cannotEstimateFee(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let plan = try await planner.plan(
            amountSats: amountSats,
            sources: [BitcoinUtxoSource(address: context.sourceAddress)],
            recipientAddress: transfer.receiver,
            changeAddress: context.sourceAddress,
            network: context.network,
            baseURL: context.baseURL
        )

        return BigUInt(UInt64(plan.feeSats))
    }

    func submit(transfer: Transfer) async throws -> String {
        let context = try resolveContext(failure: TransferServiceError.transferFailed(reason:))
        let amountSats = try resolveAmountSats(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try BitcoinKeyDerivation.deriveAccount(
                mnemonic: mnemonic,
                network: bitcoinKeyDerivationNetwork(for: context.network)
            ).firstReceiveAddress
        } catch {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic root material is invalid")
        }

        guard derivedAddress.lowercased() == context.sourceAddress.lowercased() else {
            throw TransferServiceError.transferFailed(reason: "Bitcoin mnemonic does not match selected wallet")
        }

        let result = try await sendService.send(
            BitcoinSendRequest(
                mnemonic: mnemonic,
                amountSats: amountSats,
                sources: [BitcoinUtxoSource(address: context.sourceAddress)],
                recipientAddress: transfer.receiver,
                changeAddress: context.sourceAddress,
                network: context.network,
                baseURL: context.baseURL
            )
        )

        return result.broadcastTxid
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        failure: (String) -> TransferServiceError
    ) throws -> BitcoinTransferContext {
        guard let network = bitcoinNetwork(for: chain) else {
            throw failure("Unsupported Bitcoin chain: \(chain.chainId)")
        }

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Bitcoin account address is unavailable for \(chain.chainId)")
        }

        let indexerNetwork = bitcoinIndexerNetwork(for: network)
        let normalizedSourceAddress: String
        do {
            normalizedSourceAddress = try BitcoinIndexerRoutes.normalizeAddress(
                sourceAddress,
                network: indexerNetwork
            )
        } catch {
            throw failure("Bitcoin source address is invalid")
        }

        return BitcoinTransferContext(
            sourceAddress: normalizedSourceAddress,
            network: indexerNetwork,
            baseURL: chain.externalApi?.history?.url.absoluteString
        )
    }

    private func resolveAmountSats(
        _ amount: BigUInt,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Bitcoin transfer amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let amountSats = Int64(amount.description)
        else {
            throw failure("Bitcoin transfer amount is too large")
        }

        return amountSats
    }

    private func bitcoinNetwork(for chain: ChainModel) -> UniversalWalletRegistry.BitcoinNetwork? {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.bitcoinMainnet.chainId, UniversalWalletRegistry.bitcoinMainnet.id:
            return UniversalWalletRegistry.bitcoinMainnet
        case UniversalWalletRegistry.bitcoinTestnet.chainId, UniversalWalletRegistry.bitcoinTestnet.id:
            return UniversalWalletRegistry.bitcoinTestnet
        default:
            return nil
        }
    }

    private func bitcoinIndexerNetwork(
        for network: UniversalWalletRegistry.BitcoinNetwork
    ) -> BitcoinIndexerNetwork {
        network == UniversalWalletRegistry.bitcoinTestnet ? .testnet : .mainnet
    }

    private func bitcoinKeyDerivationNetwork(
        for network: BitcoinIndexerNetwork
    ) -> BitcoinKeyDerivation.Network {
        switch network {
        case .mainnet:
            return .mainnet
        case .testnet:
            return .testnet
        }
    }
}

final class SolanaTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let rpcClient: SolanaRpcClientProtocol
    private let sendService: SolanaSendService
    private let balanceSync: SolanaBalanceSyncing
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        rpcClient: SolanaRpcClientProtocol? = nil,
        balanceSync: SolanaBalanceSyncing = SolanaBalanceSync(client: SolanaIndexerClient()),
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider()
    ) throws {
        self.wallet = wallet
        self.chain = chain
        if let rpcClient {
            self.rpcClient = rpcClient
        } else {
            self.rpcClient = try SolanaRpcClient()
        }
        self.balanceSync = balanceSync
        self.mnemonicProvider = mnemonicProvider
        let network = try Self.solanaNetwork(for: chain)
        sendService = SolanaSendService(
            rpcClient: self.rpcClient,
            balanceProvider: SolanaTransferBalanceProvider(
                balanceSync: balanceSync,
                network: network,
                baseURL: chain.externalApi?.history?.url.absoluteString
            )
        )
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        let context = try resolveContext(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        if isNativeSolAsset(transfer.chainAsset.asset, network: context.network) {
            return try await estimateNativeFee(for: transfer, context: context)
        }

        return try await estimateTokenFee(for: transfer, context: context)
    }

    private func estimateNativeFee(
        for transfer: Transfer,
        context: SolanaTransferContext
    ) async throws -> BigUInt {
        let lamports = try resolveLamports(
            transfer.amount,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        let blockhash = try await rpcClient.latestBlockhash(
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: context.sourceAddress,
            recipientAddress: transfer.receiver,
            lamports: lamports,
            recentBlockhash: blockhash.value.blockhash
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana transfer fee is unavailable")
        }

        return BigUInt(UInt64(fee))
    }

    private func estimateTokenFee(
        for transfer: Transfer,
        context: SolanaTransferContext
    ) async throws -> BigUInt {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )
        let destinationTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: transfer.receiver,
            mintAddress: token.mintAddress,
            tokenProgram: .splToken
        )
        let destinationTokenAccountExists = try await rpcClient.accountExists(
            address: destinationTokenAccount,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let blockhash = try await rpcClient.latestBlockhash(
            commitment: .confirmed,
            rpcURL: context.rpcURL
        )
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: context.sourceAddress,
            sourceTokenAccount: token.sourceTokenAccount,
            destinationTokenAccount: destinationTokenAccountExists ? destinationTokenAccount : nil,
            mintAddress: token.mintAddress,
            rawAmount: token.rawAmount,
            decimals: token.decimals,
            recentBlockhash: blockhash.value.blockhash,
            tokenProgram: .splToken,
            destinationWalletAddress: destinationTokenAccountExists ? nil : transfer.receiver
        )
        let fee = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: .confirmed,
            rpcURL: context.rpcURL
        ).value

        guard let fee else {
            throw TransferServiceError.cannotEstimateFee(reason: "Solana token transfer fee is unavailable")
        }

        return BigUInt(UInt64(fee))
    }

    func submit(transfer: Transfer) async throws -> String {
        let context = try resolveContext(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        )

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).address
        } catch {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic root material is invalid")
        }

        guard derivedAddress == context.sourceAddress else {
            throw TransferServiceError.transferFailed(reason: "Solana mnemonic does not match selected wallet")
        }

        if isNativeSolAsset(transfer.chainAsset.asset, network: context.network) {
            return try await submitNative(transfer: transfer, context: context, mnemonic: mnemonic)
        }

        return try await submitToken(transfer: transfer, context: context, mnemonic: mnemonic)
    }

    private func submitNative(
        transfer: Transfer,
        context: SolanaTransferContext,
        mnemonic: String
    ) async throws -> String {
        let lamports = try resolveLamports(
            transfer.amount,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let result = try await sendService.send(
            SolanaSendRequest(
                mnemonic: mnemonic,
                recipientAddress: transfer.receiver,
                lamports: lamports,
                rpcURL: context.rpcURL
            )
        )

        return result.signature
    }

    private func submitToken(
        transfer: Transfer,
        context: SolanaTransferContext,
        mnemonic: String
    ) async throws -> String {
        let token = try await resolveTokenTransferContext(
            for: transfer,
            context: context,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let result = try await sendService.sendTokenTransfer(
            SolanaTokenSendRequest(
                mnemonic: mnemonic,
                sourceTokenAccount: token.sourceTokenAccount,
                mintAddress: token.mintAddress,
                rawAmount: token.rawAmount,
                decimals: token.decimals,
                rpcURL: context.rpcURL,
                tokenProgram: .splToken,
                destinationWalletAddress: transfer.receiver
            )
        )

        return result.signature
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        for _: Transfer,
        failure: (String) -> TransferServiceError
    ) throws -> SolanaTransferContext {
        let network = try Self.solanaNetwork(for: chain)

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Solana account address is unavailable for \(chain.chainId)")
        }

        let normalizedSourceAddress: String
        do {
            normalizedSourceAddress = try SolanaRpcRoutes.normalizePublicKey(sourceAddress)
        } catch {
            throw failure("Solana source address is invalid")
        }

        return SolanaTransferContext(
            sourceAddress: normalizedSourceAddress,
            network: network,
            indexerBaseURL: chain.externalApi?.history?.url.absoluteString,
            rpcURL: rpcURL(for: network)
        )
    }

    private static func solanaNetwork(for chain: ChainModel) throws -> UniversalWalletRegistry.SolanaNetwork {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.solanaMainnet.chainId, UniversalWalletRegistry.solanaMainnet.id:
            return UniversalWalletRegistry.solanaMainnet
        case UniversalWalletRegistry.solanaDevnet.chainId, UniversalWalletRegistry.solanaDevnet.id:
            return UniversalWalletRegistry.solanaDevnet
        default:
            throw TransferServiceError.transferFailed(reason: "Unsupported Solana chain: \(chain.chainId)")
        }
    }

    private func isNativeSolAsset(
        _ asset: AssetModel,
        network: UniversalWalletRegistry.SolanaNetwork
    ) -> Bool {
        asset.isNative &&
            asset.id.uppercased() == network.nativeAsset.id &&
            asset.symbol.uppercased() == network.nativeAsset.symbol &&
            asset.precision == UInt16(network.nativeAsset.decimals)
    }

    private func resolveLamports(
        _ amount: BigUInt,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Solana transfer amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let lamports = Int64(amount.description)
        else {
            throw failure("Solana transfer amount is too large")
        }

        return lamports
    }

    private func resolveRawAmount(
        _ amount: BigUInt,
        unitName: String,
        failure: (String) -> TransferServiceError
    ) throws -> Int64 {
        guard amount > .zero else {
            throw failure("Solana \(unitName) amount must be positive")
        }

        guard
            amount <= BigUInt(UInt64(Int64.max)),
            let rawAmount = Int64(amount.description)
        else {
            throw failure("Solana \(unitName) amount is too large")
        }

        return rawAmount
    }

    private func resolveTokenTransferContext(
        for transfer: Transfer,
        context: SolanaTransferContext,
        failure: (String) -> TransferServiceError
    ) async throws -> SolanaTokenTransferContext {
        let rawAmount = try resolveRawAmount(
            transfer.amount,
            unitName: "token raw",
            failure: failure
        )
        let balances = try await balanceSync.balances(
            wallet: context.sourceAddress,
            network: context.network,
            baseURL: context.indexerBaseURL,
            includeTokenMetadata: false
        )
        guard let balance = balances.tokenBalances.first(where: { matchesTokenBalance($0, asset: transfer.chainAsset.asset) }) else {
            throw failure("Solana token balance is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        guard balance.tokenProgram == Self.splTokenProgramName else {
            throw failure("Solana token transfers currently support only SPL Token assets")
        }

        guard let sourceTokenAccount = balance.tokenAccountId?.nonEmpty else {
            throw failure("Solana token source account is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        guard let mintAddress = balance.contractAddress?.nonEmpty ?? balance.assetId.nonEmpty else {
            throw failure("Solana token mint is unavailable for \(transfer.chainAsset.asset.symbol)")
        }

        return SolanaTokenTransferContext(
            sourceTokenAccount: sourceTokenAccount,
            mintAddress: mintAddress,
            decimals: balance.decimals,
            rawAmount: rawAmount
        )
    }

    private func matchesTokenBalance(
        _ balance: UniversalWalletIndexedAssetBalance,
        asset: AssetModel
    ) -> Bool {
        guard !balance.isNative, balance.decimals == Int(asset.precision) else {
            return false
        }

        let identifiers = [asset.id, asset.currencyId].compactMap { $0?.nonEmpty }
        return identifiers.contains { $0 == balance.assetId || $0 == balance.contractAddress }
    }

    private func rpcURL(for network: UniversalWalletRegistry.SolanaNetwork) -> String {
        if let selectedNode = chain.selectedNode?.url.absoluteString {
            return selectedNode
        }

        return chain.nodes
            .sorted { $0.url.absoluteString < $1.url.absoluteString }
            .first?
            .url
            .absoluteString ?? network.rpcURL.absoluteString
    }

    private static let splTokenProgramName = "spl-token"
}

protocol IrohaTransferSigning {
    func buildAndSignTransfer(_ request: IrohaTransferSigningRequest) async throws -> IrohaSignedTransfer
}

struct UnavailableIrohaTransferSigner: IrohaTransferSigning {
    func buildAndSignTransfer(_: IrohaTransferSigningRequest) async throws -> IrohaSignedTransfer {
        throw TransferServiceError.transferFailed(reason: "Iroha transfer signing codec is unavailable")
    }
}

struct IrohaTransferSigningRequest: Equatable {
    let amount: String
    let assetDefinitionId: String
    let authority: String
    let chainId: String
    let derivationPath: String
    let destinationAccountId: String
    let mnemonicOrSeed: String
    let network: String
    let signingPublicKeyHex: String
    let sourceAccountId: String
    let sourceAssetId: String
}

struct IrohaSignedTransfer: Equatable {
    let signedTransaction: Data
    let transactionHashHex: String?
}

final class IrohaTransferService: TransferServiceProtocol {
    private let wallet: MetaAccountModel
    private let chain: ChainModel
    private let toriiClient: IrohaToriiClientProtocol
    private let signer: IrohaTransferSigning
    private let mnemonicProvider: UniversalWalletMnemonicProviding
    private var feeTask: Task<Void, Never>?

    init(
        wallet: MetaAccountModel,
        chain: ChainModel,
        toriiClient: IrohaToriiClientProtocol = IrohaToriiClient(),
        signer: IrohaTransferSigning = UnavailableIrohaTransferSigner(),
        mnemonicProvider: UniversalWalletMnemonicProviding = KeychainUniversalWalletMnemonicProvider()
    ) {
        self.wallet = wallet
        self.chain = chain
        self.toriiClient = toriiClient
        self.signer = signer
        self.mnemonicProvider = mnemonicProvider
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        _ = try resolveContext(
            for: transfer,
            failure: TransferServiceError.cannotEstimateFee(reason:)
        )

        return .zero
    }

    func submit(transfer: Transfer) async throws -> String {
        let context = try resolveContext(
            for: transfer,
            failure: TransferServiceError.transferFailed(reason:)
        )
        let signedTransfer = try await signer.buildAndSignTransfer(context.signingRequest)

        guard !signedTransfer.signedTransaction.isEmpty else {
            throw TransferServiceError.transferFailed(reason: "Iroha transfer signer returned an empty transaction")
        }

        let receipt = try await toriiClient.submitTransaction(
            noritoBytes: signedTransfer.signedTransaction,
            baseURL: context.toriiBaseURL
        )

        return signedTransfer.transactionHashHex
            ?? receipt.payload.signedTransactionHash
            ?? receipt.payload.txHash
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        feeTask?.cancel()
        feeTask = Task { [weak self, weak listener] in
            guard let self else {
                return
            }

            do {
                let fee = try await self.estimateFee(for: transfer)
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFee(fee: fee)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                listener?.didReceiveFeeError(feeError: error)
            }
        }
    }

    func unsubscribe() {
        feeTask?.cancel()
        feeTask = nil
    }

    private func resolveContext(
        for transfer: Transfer,
        failure: (String) -> TransferServiceError
    ) throws -> IrohaTransferContext {
        let network = try Self.irohaNetwork(
            for: chain,
            failure: failure
        )
        let toriiBaseURL = try Self.toriiBaseURL(
            for: chain,
            network: network,
            failure: failure
        )

        guard let sourceAddress = UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet) else {
            throw failure("Iroha account address is unavailable for \(chain.chainId)")
        }

        let sourceDetails: IrohaAddressDetails
        do {
            sourceDetails = try IrohaAddressCodec.parse(
                sourceAddress,
                expectedDiscriminant: network.chainDiscriminant
            )
        } catch {
            throw failure("Iroha source address is invalid")
        }

        let destinationAddress: String
        do {
            destinationAddress = try IrohaAddressCodec.parse(
                transfer.receiver,
                expectedDiscriminant: network.chainDiscriminant
            ).i105
        } catch {
            throw failure("Iroha recipient address is invalid")
        }

        guard let mnemonic = try mnemonicProvider.mnemonic(for: wallet, chain: chain) else {
            throw failure("Iroha mnemonic root material is unavailable")
        }

        let derivedAddress: String
        do {
            derivedAddress = try IrohaKeyDerivation.deriveAddress(
                mnemonic: mnemonic,
                chainDiscriminant: network.chainDiscriminant
            ).i105
        } catch {
            throw failure("Iroha mnemonic root material is invalid")
        }

        guard derivedAddress == sourceDetails.i105 else {
            throw failure("Iroha mnemonic does not match selected wallet")
        }

        let assetDefinitionId = try Self.normalizeAssetDefinitionId(
            transfer.chainAsset.asset.id,
            failure: failure
        )
        let amount = try Self.normalizeAmount(
            rawAmount: transfer.amount,
            precision: Int(transfer.chainAsset.asset.precision),
            failure: failure
        )

        return IrohaTransferContext(
            toriiBaseURL: toriiBaseURL,
            signingRequest: IrohaTransferSigningRequest(
                amount: amount,
                assetDefinitionId: assetDefinitionId,
                authority: sourceDetails.i105,
                chainId: network.chainId,
                derivationPath: UniversalWalletDerivationPaths.irohaDefault,
                destinationAccountId: destinationAddress,
                mnemonicOrSeed: mnemonic,
                network: Self.networkKey(for: network),
                signingPublicKeyHex: sourceDetails.publicKeyHex,
                sourceAccountId: sourceDetails.i105,
                sourceAssetId: "\(assetDefinitionId)#\(sourceDetails.i105)"
            )
        )
    }

    private static func irohaNetwork(
        for chain: ChainModel,
        failure: (String) -> TransferServiceError
    ) throws -> UniversalWalletRegistry.IrohaNetwork {
        switch chain.chainId.lowercased() {
        case UniversalWalletRegistry.taira.chainId, UniversalWalletRegistry.taira.id:
            return UniversalWalletRegistry.taira
        case UniversalWalletRegistry.nexus.chainId, UniversalWalletRegistry.nexus.id:
            return UniversalWalletRegistry.nexus
        default:
            throw failure("Unsupported Iroha chain: \(chain.chainId)")
        }
    }

    private static func toriiBaseURL(
        for chain: ChainModel,
        network: UniversalWalletRegistry.IrohaNetwork,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        if let url = chain.externalApi?.history?.url.absoluteString.nonEmpty {
            return url
        }

        guard let url = network.toriiBaseURL?.absoluteString.nonEmpty else {
            throw failure("Iroha Torii endpoint is not configured for \(chain.chainId)")
        }

        return url
    }

    private static func normalizeAmount(
        rawAmount: BigUInt,
        precision: Int,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        guard rawAmount > .zero else {
            throw failure("Iroha transfer amount must be positive")
        }

        guard precision >= 0, precision <= 28 else {
            throw failure("Iroha asset precision is unsupported")
        }

        let raw = rawAmount.description
        guard precision > 0 else {
            return raw
        }

        let padded = raw.count <= precision
            ? String(repeating: "0", count: precision - raw.count + 1) + raw
            : raw
        let splitIndex = padded.index(padded.endIndex, offsetBy: -precision)
        let whole = String(padded[..<splitIndex])
        var fraction = String(padded[splitIndex...])
        while fraction.last == "0" {
            fraction.removeLast()
        }

        return fraction.isEmpty ? whole : "\(whole).\(fraction)"
    }

    private static func normalizeAssetDefinitionId(
        _ assetDefinitionId: String,
        failure: (String) -> TransferServiceError
    ) throws -> String {
        let pattern = #"^[^\s%/?:#]+#[^\s%/?:#]+$"#
        guard assetDefinitionId.range(of: pattern, options: .regularExpression) != nil else {
            throw failure("Iroha asset definition id is invalid")
        }

        return assetDefinitionId
    }

    private static func networkKey(for network: UniversalWalletRegistry.IrohaNetwork) -> String {
        if network == UniversalWalletRegistry.taira {
            return "taira"
        }

        if network == UniversalWalletRegistry.nexus {
            return "nexus"
        }

        return network.id
    }
}

private struct BitcoinTransferContext {
    let sourceAddress: String
    let network: BitcoinIndexerNetwork
    let baseURL: String?
}

private struct SolanaTransferContext {
    let sourceAddress: String
    let network: UniversalWalletRegistry.SolanaNetwork
    let indexerBaseURL: String?
    let rpcURL: String
}

private struct SolanaTokenTransferContext {
    let sourceTokenAccount: String
    let mintAddress: String
    let decimals: Int
    let rawAmount: Int64
}

private struct IrohaTransferContext {
    let toriiBaseURL: String
    let signingRequest: IrohaTransferSigningRequest
}

private final class SolanaTransferBalanceProvider: SolanaSendBalanceProvider {
    private let balanceSync: SolanaBalanceSyncing
    private let network: UniversalWalletRegistry.SolanaNetwork
    private let baseURL: String?

    init(
        balanceSync: SolanaBalanceSyncing,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String?
    ) {
        self.balanceSync = balanceSync
        self.network = network
        self.baseURL = baseURL
    }

    func balances(wallet: String) async throws -> SolanaBalanceSyncResult {
        try await balanceSync.balances(
            wallet: wallet,
            network: network,
            baseURL: baseURL,
            includeTokenMetadata: false
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
