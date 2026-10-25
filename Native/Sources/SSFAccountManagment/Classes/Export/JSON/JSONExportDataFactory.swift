import Foundation
import SoraKeystore
import SSFKeyPair
import SSFModels

enum JSONExportDataFactoryError: Error {
    case invalidData
}

// sourcery: AutoMockable
protocol JSONExportDataFactoryProtocol {
    func createJSONExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        chainAccount: ChainAccountResponse,
        chain: ChainModel,
        password: String,
        address: String,
        genesisHash: String?
    ) throws -> JSONExportData?
}

struct JSONExportDataFactory: JSONExportDataFactoryProtocol {
    private let exportJsonWrapper: KeystoreExportWrapperProtocol

    init(exportJsonWrapper: KeystoreExportWrapperProtocol) {
        self.exportJsonWrapper = exportJsonWrapper
    }

    func createJSONExportData(
        metaId: MetaAccountId,
        accountId: AccountId?,
        chainAccount: ChainAccountResponse,
        chain: ChainModel,
        password: String,
        address: String,
        genesisHash: String?
    ) throws -> JSONExportData? {
        let data = try exportJsonWrapper.export(
            chainAccount: chainAccount,
            password: password,
            address: address,
            metaId: metaId,
            accountId: accountId,
            genesisHash: genesisHash
        )

        if let result = String(data: data, encoding: .utf8) {
            let fileUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "/\(address)).json")
            try result.write(toFile: fileUrl.path, atomically: true, encoding: .utf8)

            return JSONExportData(
                data: result,
                chain: chain,
                cryptoType: nil,
                fileURL: fileUrl
            )
        }

        return nil
    }
}
