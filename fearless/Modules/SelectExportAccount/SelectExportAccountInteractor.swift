import UIKit
import RobinHood

final class SelectExportAccountInteractor {
    // MARK: - Private properties

    private weak var output: SelectExportAccountInteractorOutput?
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let metaAccount: MetaAccountModel

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        metaAccount: MetaAccountModel
    ) {
        self.chainRepository = chainRepository
        self.metaAccount = metaAccount
    }
}

// MARK: - SelectExportAccountInteractorInput

extension SelectExportAccountInteractor: SelectExportAccountInteractorInput {
    func setup(with output: SelectExportAccountInteractorOutput) {
        self.output = output
    }
}
