import UIKit

final class PolkaswapTransaktionSettingsInteractor {
    // MARK: - Private properties

    private weak var output: PolkaswapTransaktionSettingsInteractorOutput?
}

// MARK: - PolkaswapTransaktionSettingsInteractorInput

extension PolkaswapTransaktionSettingsInteractor: PolkaswapTransaktionSettingsInteractorInput {
    func setup(with output: PolkaswapTransaktionSettingsInteractorOutput) {
        self.output = output
    }
}
