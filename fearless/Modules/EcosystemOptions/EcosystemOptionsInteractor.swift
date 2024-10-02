import UIKit
import SoraKeystore
import SSFModels

protocol EcosystemOptionsInteractorOutput: AnyObject {}

final class EcosystemOptionsInteractor {
    // MARK: - Private properties
    private weak var output: EcosystemOptionsInteractorOutput?

    private let wallet: MetaAccountModel
    private let keystore: KeystoreProtocol
    private let availableExportOptionsProvider: AvailableExportOptionsProviderProtocol

    init(
        wallet: MetaAccountModel,
        keystore: KeystoreProtocol,
        availableExportOptionsProvider: AvailableExportOptionsProviderProtocol
    ) {
        self.wallet = wallet
        self.keystore = keystore
        self.availableExportOptionsProvider = availableExportOptionsProvider
    }
}

// MARK: - EcosystemOptionsInteractorInput
extension EcosystemOptionsInteractor: EcosystemOptionsInteractorInput {
    func setup(with output: EcosystemOptionsInteractorOutput) {
        self.output = output
    }

    func getAvailableExportOptions(for ecosystem: Ecosystem) -> [ExportOption] {
        let options = availableExportOptionsProvider.getAvailableExportOptions(
            for: wallet,
            accountId: nil,
            ecosystem: ecosystem
        )
        return options
    }
}
