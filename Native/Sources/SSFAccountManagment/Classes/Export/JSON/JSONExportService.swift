import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFExtrinsicKit
import SSFModels
import SSFUtils

enum JSONExportServiceError: Error {
    case missingAccount
    case missingJson
}

// To regenerate mock object
// Change '_AutoMockable' to 'AutoMockable'
// Run build to generate the mock
// Replace 'class' to 'actor' in genereated mock file
// Change 'AutoMockable' to '_AutoMockable' to avoid future generations
// sourcery: _AutoMockable
protocol JSONExportServiceProtocol: Actor {
    func export(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    ) -> [JSONExportData]

    func exportAccount(
        address: String,
        password: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> JSONExportData
}

actor JSONExportService {
    private let genesisService: GenesisBlockHashWorkerProtocol
    private let factory: JSONExportDataFactoryProtocol

    init(genesisService: GenesisBlockHashWorkerProtocol, factory: JSONExportDataFactoryProtocol) {
        self.genesisService = genesisService
        self.factory = factory
    }
}

extension JSONExportService: JSONExportServiceProtocol {
    func export(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    ) -> [JSONExportData] {
        var jsons: [JSONExportData] = []

        for chainAccount in accounts {
            let accountId = chainAccount.account.isChainAccount ? chainAccount.account
                .accountId : nil

            do {
                let address = try AddressFactory.address(
                    for: chainAccount.account.accountId,
                    chainFormat: chainAccount.chain
                        .chainFormat
                )

                if let json = try? factory.createJSONExportData(
                    metaId: wallet.metaId,
                    accountId: accountId,
                    chainAccount: chainAccount.account,
                    chain: chainAccount.chain,
                    password: password,
                    address: address,
                    genesisHash: nil
                ) {
                    jsons.append(json)
                }
            } catch {}
        }

        return jsons
    }

    func exportAccount(
        address: String,
        password: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) async throws -> JSONExportData {
        guard let chainAccount = try? wallet.fetchChainAccountFor(chain: chain, address: address) else {
            throw JSONExportServiceError.missingAccount
        }

        let genesisHash = await genesisService.getGenesisHash()
        let accountId = chainAccount.isChainAccount ? chainAccount.accountId : nil

        if let data = try factory.createJSONExportData(
            metaId: wallet.metaId,
            accountId: accountId,
            chainAccount: chainAccount,
            chain: chain,
            password: password,
            address: address,
            genesisHash: genesisHash
        ) {
            return data
        } else {
            throw JSONExportServiceError.missingJson
        }
    }
}
