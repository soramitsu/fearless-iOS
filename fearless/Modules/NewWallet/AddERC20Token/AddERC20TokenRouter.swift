import Foundation
import SoraFoundation
import SoraUI

final class AddERC20TokenRouter: AddERC20TokenRouterInput {
    // MARK: - Private properties

    private let localizationManager: LocalizationManagerProtocol

    // MARK: - Constructors

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    // MARK: - AddERC20TokenRouterInput
} 
