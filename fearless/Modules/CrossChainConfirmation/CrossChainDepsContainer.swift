import Foundation
import SoraFoundation
import SSFXCM
import SSFModels
import SSFCrypto
import SoraKeystore
import SSFUtils

final class CrossChainDepsContainer {
    enum DepsError: Error {
        case missingChainResponse
        case missingOriginalChainTypes
        case missingDestChainTypes
    }

    struct CrossChainConfirmationDeps {
        let xcmService: XcmExtrinsicServiceProtocol
    }

    private var cachedDependencies: [String: CrossChainConfirmationDeps] = [:]
    private let wallet: MetaAccountModel
    private let chainsTypesMap: [String: Data]
    private lazy var operationQueue: OperationQueue = {
        OperationQueue()
    }()

    init(
        wallet: MetaAccountModel,
        chainsTypesMap: [String: Data]
    ) {
        self.wallet = wallet
        self.chainsTypesMap = chainsTypesMap
    }

    // MARK: - Public methods

    func prepareDepsFor(
        originalChainAsset: ChainAsset,
        destChainModel: ChainModel,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol,
        destRuntimeMetadataItem: RuntimeMetadataItemProtocol
    ) throws -> CrossChainConfirmationDeps {
        let key = generateCacheKey(for: originalChainAsset, destinationChain: destChainModel)
        if let cached = cachedDependencies[key] {
            return cached
        }

        let xcmService = try createXcmService(
            wallet: wallet,
            originalChainAsset: originalChainAsset,
            destChainModel: destChainModel,
            originalRuntimeMetadataItem: originalRuntimeMetadataItem,
            destRuntimeMetadataItem: destRuntimeMetadataItem
        )
        let deps = CrossChainConfirmationDeps(
            xcmService: xcmService
        )

        cachedDependencies[key] = deps

        return deps
    }

    // MARK: - Private methods

    private func generateCacheKey(for originalChainAsset: ChainAsset, destinationChain: ChainModel) -> String {
        "\(originalChainAsset.chain.chainId)-\(destinationChain.chainId)"
    }

    private func createXcmService(
        wallet: MetaAccountModel,
        originalChainAsset: ChainAsset,
        destChainModel: ChainModel,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol,
        destRuntimeMetadataItem: RuntimeMetadataItemProtocol
    ) throws -> XcmExtrinsicServiceProtocol {
        let request = originalChainAsset.chain.accountRequest()
        guard let response = wallet.fetch(for: request) else {
            throw DepsError.missingChainResponse
        }

        let chainFormat: ChainFormat = originalChainAsset.chain.isEthereumBased
            ? .ethereum
            : .substrate(originalChainAsset.chain.addressPrefix)
        let cryptoType = response.cryptoType
        let accountId = response.accountId

        guard let originalChainTypes = chainsTypesMap[originalChainAsset.chain.chainId] else {
            throw DepsError.missingOriginalChainTypes
        }
        let originalRuntimeData = XcmAssembly.RuntimeCodingServiceData(
            chainMetadata: originalRuntimeMetadataItem,
            chainTypes: originalChainTypes
        )

        let extrinsicServiceData = XcmAssembly.ExtrinsicServiceData(
            accountId: accountId,
            chainFormat: chainFormat.asSfCrypto()
        )

        let secretKeyData = try fetchSecretKey(
            for: originalChainAsset.chain,
            metaId: wallet.metaId,
            accountResponse: response
        )

        let signingWrapperData = XcmAssembly.SigningWrapperData(
            publicKeyData: response.publicKey,
            secretKeyData: secretKeyData
        )

        let fromChainData = XcmAssembly.FromChainData(
            chainAsset: originalChainAsset,
            cryptoType: SFCryptoType(cryptoType.utilsType),
            runtimeData: originalRuntimeData,
            extrinsicServiceData: extrinsicServiceData,
            signingWrapperData: signingWrapperData
        )

        guard let destChainTypes = chainsTypesMap[destChainModel.chainId] else {
            throw DepsError.missingDestChainTypes
        }
        let destRuntimeData = XcmAssembly.RuntimeCodingServiceData(
            chainMetadata: destRuntimeMetadataItem,
            chainTypes: destChainTypes
        )
        let service = try XcmAssembly.createService(
            fromChainData: fromChainData,
            destChainModel: destChainModel,
            destRuntimeData: destRuntimeData
        )

        return service
    }

    private func fetchSecretKey(
        for chain: ChainModel,
        metaId: String,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }
}
