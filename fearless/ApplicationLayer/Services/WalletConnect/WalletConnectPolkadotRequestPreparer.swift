import Foundation
import BigInt
import FearlessWalletConnect
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import SoraFoundation

protocol WalletConnectPolkadotRuntimeProviding {
    func coderFactory(for chain: ChainModel) async throws -> RuntimeCoderFactoryProtocol
    /// The inclusion fee the chain quotes for an encoded extrinsic, without the tip.
    func inclusionFee(of extrinsic: Data, chain: ChainModel) async throws -> BigUInt
}

final class WalletConnectPolkadotRuntimeProvider: WalletConnectPolkadotRuntimeProviding {
    private let chainRegistry: ChainRegistryProtocol
    private let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }

    func coderFactory(for chain: ChainModel) async throws -> RuntimeCoderFactoryProtocol {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            throw RuntimeProviderError.providerUnavailable
        }
        return try await runtimeProvider.fetchCoderFactory()
    }

    func inclusionFee(of extrinsic: Data, chain: ChainModel) async throws -> BigUInt {
        guard let connection = chainRegistry.getConnection(for: chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operation = JSONRPCListOperation<RuntimeDispatchInfo>(
            engine: connection,
            method: RPCMethod.paymentInfo,
            parameters: [extrinsic.toHex(includePrefix: true)]
        )

        let info: RuntimeDispatchInfo = try await withCheckedThrowingContinuation { continuation in
            operation.completionBlock = {
                do {
                    try continuation.resume(returning: operation.extractNoCancellableResultData())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            operationQueue.addOperation(operation)
        }

        let fee = info.inclusionFee
        return fee.baseFee + fee.lenFee + fee.adjustedWeightFee
    }
}

protocol WalletConnectPolkadotRequestPreparing {
    func prepareTransaction(
        params: AnyCodable,
        chain: ChainModel,
        account: ChainAccountResponse
    ) async throws -> WalletConnectPolkadotExtrinsic
}

/// Checks a `polkadot_signTransaction` payload against the chain the confirmation shows
/// and decodes its call. A payload for another genesis hash or runtime version, or a call
/// the wallet cannot decode back to exactly the bytes the dApp sent, is declined.
final class WalletConnectPolkadotRequestPreparer: WalletConnectPolkadotRequestPreparing {
    private static let transferCalls: Set<String> = ["transfer", "transfer_keep_alive", "transfer_allow_death"]

    private let runtime: WalletConnectPolkadotRuntimeProviding

    init(runtime: WalletConnectPolkadotRuntimeProviding = WalletConnectPolkadotRuntimeProvider()) {
        self.runtime = runtime
    }

    func prepareTransaction(
        params: AnyCodable,
        chain: ChainModel,
        account: ChainAccountResponse
    ) async throws -> WalletConnectPolkadotExtrinsic {
        guard let request = try? params.get(WalletConnectPolkadotTransaction.self) else {
            throw WalletConnectRequestError.unsupported
        }

        let payload = request.transactionPayload
        let requestAccount = try WalletConnectAccountBinding.accountId(of: request.address, chain: chain)
        let payloadAccount = try WalletConnectAccountBinding.accountId(of: payload.address, chain: chain)
        guard requestAccount == account.accountId, payloadAccount == account.accountId else {
            throw WalletConnectRequestError.accountNotApproved
        }

        guard
            let payloadGenesis = try? Data(hexStringSSF: payload.genesisHash),
            let chainGenesis = try? Data(hexStringSSF: chain.chainId),
            payloadGenesis == chainGenesis
        else {
            throw WalletConnectRequestError.networkMismatch
        }

        let coderFactory: RuntimeCoderFactoryProtocol
        do {
            coderFactory = try await runtime.coderFactory(for: chain)
        } catch {
            throw WalletConnectRequestError.unsupported
        }

        let transaction = try Self.decode(payload: payload, chain: chain, coderFactory: coderFactory)

        let fee: BigUInt
        do {
            let extrinsic = try Self.makeFeeEstimationExtrinsic(
                for: transaction,
                account: account,
                chain: chain,
                coderFactory: coderFactory
            )
            fee = try await runtime.inclusionFee(of: extrinsic, chain: chain)
        } catch {
            throw WalletConnectRequestError.feeUnavailable
        }

        return WalletConnectPolkadotExtrinsic(
            payload: transaction.payload,
            specVersion: transaction.specVersion,
            transactionVersion: transaction.transactionVersion,
            nonce: transaction.nonce,
            era: transaction.era,
            tip: transaction.tip,
            call: transaction.call,
            transfer: transaction.transfer,
            fee: fee
        )
    }

    // MARK: - Decoding

    struct DecodedTransaction {
        let payload: TransactionPayload
        let specVersion: UInt32
        let transactionVersion: UInt32
        let nonce: UInt32
        let era: Era
        let tip: BigUInt
        let call: RuntimeCall<JSON>
        let transfer: WalletConnectSubstrateTransfer?
    }

    static func decode(
        payload: TransactionPayload,
        chain: ChainModel,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> DecodedTransaction {
        guard
            let specVersion = BigUInt.fromHexString(payload.specVersion).flatMap({ UInt32(exactly: $0) }),
            let transactionVersion = BigUInt.fromHexString(payload.transactionVersion).flatMap({ UInt32(exactly: $0) }),
            let nonce = BigUInt.fromHexString(payload.nonce).flatMap({ UInt32(exactly: $0) }),
            let tip = BigUInt.fromHexString(payload.tip),
            let era = try? decodeEra(payload.era),
            (try? Data(hexStringSSF: payload.blockHash))?.count == 32
        else {
            throw WalletConnectRequestError.unsupported
        }

        // A signature for another runtime version would not be for the chain shown.
        guard specVersion == coderFactory.specVersion, transactionVersion == coderFactory.txVersion else {
            throw WalletConnectRequestError.runtimeMismatch(chainName: chain.name)
        }

        let call = try decodeCall(payload.method, coderFactory: coderFactory)
        let transfer = try transfer(in: call)

        // Any other call is shown in full with its arguments and the calls it carries, or not signed at all.
        if transfer == nil {
            let text = WalletConnectSubstrateCallText.make(chain: chain, locale: LocalizationManager.shared.selectedLocale)
            guard text.fits(call) else {
                throw WalletConnectRequestError.unsupported
            }
        }

        return DecodedTransaction(
            payload: payload,
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            nonce: nonce,
            era: era,
            tip: tip,
            call: call,
            transfer: transfer
        )
    }

    /// Decodes the call and requires that encoding it again gives exactly the dApp's bytes,
    /// so the call shown is the call signed.
    static func decodeCall(_ method: String, coderFactory: RuntimeCoderFactoryProtocol) throws -> RuntimeCall<JSON> {
        do {
            let callData = try Data(hexStringSSF: method)
            let decoder = try coderFactory.createDecoder(from: callData)
            let call: RuntimeCall<JSON> = try decoder.read(of: KnownType.call.rawValue)
            guard decoder.remained == 0 else {
                throw WalletConnectRequestError.unsupported
            }

            let encoder = coderFactory.createEncoder()
            try encoder.append(json: call.toScaleCompatibleJSON(), type: GenericType.call.name)
            guard try encoder.encode() == callData else {
                throw WalletConnectRequestError.unsupported
            }

            return call
        } catch {
            throw WalletConnectRequestError.unsupported
        }
    }

    static func transfer(in call: RuntimeCall<JSON>) throws -> WalletConnectSubstrateTransfer? {
        guard call.moduleName == "Balances", transferCalls.contains(call.callName) else {
            return nil
        }

        guard let arguments = try? call.args.map(to: TransferCall.self) else {
            throw WalletConnectRequestError.unsupported
        }

        switch arguments.dest {
        case let .accoundId(recipient), let .address32(recipient), let .address20(recipient):
            return WalletConnectSubstrateTransfer(recipient: recipient, amount: arguments.value)
        default:
            // An index or raw destination cannot be shown as an account.
            throw WalletConnectRequestError.unsupported
        }
    }

    private static func decodeEra(_ scale: String) throws -> Era {
        let data = try Data(hexStringSSF: scale)
        let scaleDecoder = try ScaleDecoder(data: data)
        return try Era(scaleDecoder: scaleDecoder)
    }

    // MARK: - Building

    /// The builder the signer and the fee estimate share, from the checked payload fields.
    static func makeBuilder(
        payload: TransactionPayload,
        specVersion: UInt32,
        transactionVersion: UInt32,
        nonce: UInt32,
        era: Era,
        tip: BigUInt,
        call: RuntimeCall<JSON>
    ) throws -> ExtrinsicBuilderProtocol {
        try ExtrinsicBuilder(
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            genesisHash: payload.genesisHash
        )
        .with(nonce: nonce)
        .with(era: era, blockHash: payload.blockHash)
        .with(tip: tip)
        .adding(call: call)
    }

    private static func makeFeeEstimationExtrinsic(
        for transaction: DecodedTransaction,
        account: ChainAccountResponse,
        chain: ChainModel,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        let cryptoType = account.cryptoType
        let address = coderFactory.metadata.multiAddressParameter(
            accountId: account.accountId,
            chainFormat: chain.chainFormat.asSfCrypto()
        )

        return try makeBuilder(
            payload: transaction.payload,
            specVersion: transaction.specVersion,
            transactionVersion: transaction.transactionVersion,
            nonce: transaction.nonce,
            era: transaction.era,
            tip: transaction.tip,
            call: transaction.call
        )
        .with(address: address)
        .signing(
            by: { data in try DummySigner(cryptoType: cryptoType).sign(data).rawData() },
            of: cryptoType,
            using: coderFactory.createEncoder(),
            metadata: coderFactory.metadata
        )
        .build(encodingBy: coderFactory.createEncoder(), metadata: coderFactory.metadata)
    }
}

extension WalletConnectPolkadotExtrinsic {
    func makeBuilder() throws -> ExtrinsicBuilderProtocol {
        try WalletConnectPolkadotRequestPreparer.makeBuilder(
            payload: payload,
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            nonce: nonce,
            era: era,
            tip: tip,
            call: call
        )
    }
}

/// The `<Bytes>…</Bytes>` envelope polkadot-js puts around raw messages, so a message
/// signature can never be a signature over a transaction payload.
enum WalletConnectBytesEnvelope {
    static let prefix = Data("<Bytes>".utf8)
    static let suffix = Data("</Bytes>".utf8)

    /// Like polkadot-js `u8aWrapBytes`, a message that is already wrapped is signed as it
    /// is. Unlike it, a message starting with the Ethereum prefix is wrapped too, so dApp
    /// bytes are never signed bare with a Substrate key.
    static func wrap(_ message: Data) -> Data {
        isWrapped(message) ? message : prefix + message + suffix
    }

    static func isWrapped(_ message: Data) -> Bool {
        message.count >= prefix.count + suffix.count &&
            message.starts(with: prefix) &&
            message.suffix(suffix.count).elementsEqual(suffix)
    }
}
