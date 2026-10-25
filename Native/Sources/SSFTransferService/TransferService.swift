import BigInt
import Foundation
import SSFModels
import SSFUtils

public protocol TransferService: AnyObject {
    func submit(_ transfer: TransferType, for chainAsset: ChainAsset) async throws -> String
    func estimateFee(_ transfer: TransferType, for chainAsset: ChainAsset) async
        -> AsyncThrowingStream<BigUInt, Error>
}

public actor TransferServiceDefault: TransferService {
    private let wallet: MetaAccountModel
    private let secretKeyData: Data

    private var existSubstrateServices: [String: SubstrateTransferService] = [:]
    private var existEthereumServices: [String: EthereumTransferService] = [:]

    public init(
        wallet: MetaAccountModel,
        secretKeyData: Data
    ) {
        self.wallet = wallet
        self.secretKeyData = secretKeyData
    }

    public func submit(
        _ transfer: TransferType,
        for chainAsset: ChainAsset
    ) async throws -> String {
        switch transfer {
        case let .substrate(substrateTransfer):
            let service = try await createSubstrateService(for: chainAsset.chain)
            return try await service.submit(transfer: substrateTransfer, chainAsset: chainAsset)
        case let .ethereum(ethereumTransfer):
            let service = try await createEthereumTransferService(for: chainAsset.chain)
            return try await service.submit(transfer: ethereumTransfer, chainAsset: chainAsset)
        case let .xorless(xorlessTransfer):
            let service = try await createSubstrateService(for: chainAsset.chain)
            return try await service.submit(transfer: xorlessTransfer, chainAsset: chainAsset)
        }
    }

    public func estimateFee(
        _ transfer: TransferType,
        for chainAsset: ChainAsset
    ) async -> AsyncThrowingStream<BigUInt, Error> {
        do {
            switch transfer {
            case let .substrate(substrateTransfer):
                let service = try await createSubstrateService(for: chainAsset.chain)
                return service.estimateFee(for: substrateTransfer, chainAsset: chainAsset)
            case let .ethereum(ethereumTransfer):
                let service = try await createEthereumTransferService(for: chainAsset.chain)
                return await service.estimateFee(for: ethereumTransfer, chainAsset: chainAsset)
            case let .xorless(xorlessTransfer):
                let service = try await createSubstrateService(for: chainAsset.chain)
                return service.estimateFee(for: xorlessTransfer, chainAsset: chainAsset)
            }
        } catch {
            return Fail<BigUInt, Error>(error: error).finishedAsyncThrowingStream()
        }
    }

    // MARK: - Private methods

    private func createSubstrateService(
        for chain: ChainModel
    ) async throws -> SubstrateTransferService {
        if let existService = existSubstrateServices[chain.chainId] {
            return existService
        }

        let service = try await SubstrateTransferAssembly().createSubstrateService(
            wallet: wallet,
            chain: chain,
            secretKeyData: secretKeyData
        )

        existSubstrateServices[chain.chainId] = service
        return service
    }

    private func createEthereumTransferService(
        for chain: ChainModel
    ) async throws -> EthereumTransferService {
        if let existService = existEthereumServices[chain.chainId] {
            return existService
        }

        let service = try await EthereumTransferServiceAssembly().createEthereumTransferService(
            wallet: wallet,
            chain: chain,
            secretKeyData: secretKeyData
        )

        existEthereumServices[chain.chainId] = service
        return service
    }
}
