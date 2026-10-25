import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import UIKit

enum MnemonicExportServiceError: Error {
    case missingAccount
    case missingEntropy
    case missingMnemomic
}

// sourcery: AutoMockable
protocol MnemonicExportServiceProtocol: AnyObject {
    func fetchExportDataFor(wallet: MetaAccountModel, accounts: [ChainAccountInfo])
        -> [MnemonicExportData]
    func fetchExportDataFor(address: String, chain: ChainModel, wallet: MetaAccountModel) throws
        -> MnemonicExportData
}

final class MnemonicExportService {
    let factory: MnemonicExportDataFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        factory: MnemonicExportDataFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.factory = factory
        self.operationManager = operationManager
    }
}

extension MnemonicExportService: MnemonicExportServiceProtocol {
    func fetchExportDataFor(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo]
    ) -> [MnemonicExportData] {
        var models: [MnemonicExportData] = []

        for chainAccount in accounts {
            let accountId = chainAccount.account.isChainAccount ? chainAccount.account
                .accountId : nil
            let cryptoType = chainAccount.account.isEthereumBased ? nil : chainAccount.account
                .cryptoType

            if let data = try? factory.createMnemonicExportData(
                metaId: wallet.metaId,
                accountId: accountId,
                cryptoType: cryptoType,
                chain: chainAccount.chain
            ) {
                models.append(data)
            }
        }

        return models
    }

    func fetchExportDataFor(
        address: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    ) throws -> MnemonicExportData {
        guard let chainRespone = try? wallet.fetchChainAccountFor(chain: chain, address: address) else {
            throw MnemonicExportServiceError.missingAccount
        }

        let accountId = chainRespone.isChainAccount ? wallet.fetch(for: chain.accountRequest())?
            .accountId : nil

        if let data = try? factory.createMnemonicExportData(
            metaId: wallet.metaId,
            accountId: accountId,
            cryptoType: chainRespone.cryptoType,
            chain: chain
        ) {
            return data
        } else {
            throw MnemonicExportServiceError.missingMnemomic
        }
    }
}
