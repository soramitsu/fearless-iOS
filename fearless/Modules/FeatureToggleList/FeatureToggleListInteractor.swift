import UIKit
import RobinHood

protocol FeatureToggleListInteractorOutput: AnyObject {}

final class FeatureToggleListInteractor {
    // MARK: - Private properties

    private weak var output: FeatureToggleListInteractorOutput?

    private lazy var storage: LocalToggleService = {
        ServiceAssembly.shared.localToggle
    }()
}

// MARK: - FeatureToggleListInteractorInput

extension FeatureToggleListInteractor: FeatureToggleListInteractorInput {
    var toggles: [LocalListToggle] {
        storage.list
    }

    func set(toggle: LocalListToggle) {
        storage.set(toggle: toggle)
    }

    func setup(with output: FeatureToggleListInteractorOutput) {
        self.output = output
    }
}
