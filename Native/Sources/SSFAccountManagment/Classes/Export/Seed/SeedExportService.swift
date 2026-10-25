import Foundation
import RobinHood
import SoraKeystore
import SSFModels

enum SeedExportServiceError: Error {
    case missingSeed
    case missingAccount
}

// sourcery: AutoMockable
protocol SeedExportServiceProtocol {
    func fetchExportDataFor(wallet: MetaAccountModel, accounts: [ChainAccountInfo])
        -> [SeedExportData]
    func fetchExportDataFor(
        address: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> SeedExportData
}

public final class SeedExportService: SeedExportServiceProtocol {
    private let operationManager: OperationManagerProtocol
    private let seedFactory: SeedExportDataFactoryProtocol

    init(
        seedFactory: SeedExportDataFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.seedFactory = seedFactory
        self.operationManager = operationManager
    }

    func fetchExportDataFor(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo]
    ) -> [SeedExportData] {
        var seeds: [SeedExportData] = []

        for chainAccount in accounts {
            let accountId = chainAccount.account.isChainAccount ? chainAccount.account
                .accountId : nil

            if let seedData = try? seedFactory.createSeedExportData(
                metaId: wallet.metaId,
                accountId: accountId,
                cryptoType: chainAccount.account.cryptoType,
                chain: chainAccount.chain
            ) {
                seeds.append(seedData)
            }
        }

        return seeds
    }

    func fetchExportDataFor(
        address: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) throws -> SeedExportData {
        guard let chainRespone = try? wallet.fetchChainAccountFor(chain: chain, address: address) else {
            throw SeedExportServiceError.missingAccount
        }

        let accountId = chainRespone.isChainAccount ? wallet.fetch(for: chain.accountRequest())?
            .accountId : nil

        if let seedData = try? seedFactory.createSeedExportData(
            metaId: wallet.metaId,
            accountId: accountId,
            cryptoType: chainRespone.cryptoType,
            chain: chain
        ) {
            return seedData
        } else {
            throw SeedExportServiceError.missingSeed
        }
    }
}
