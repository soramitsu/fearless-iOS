import Foundation
import SoraKeystore

final class EducationStoriesInteractor {
    private weak var output: EducationStoriesInteractorOutput?

    private let userDefaultsStorage: SettingsManagerProtocol

    init(userDefaultsStorage: SettingsManagerProtocol) {
        self.userDefaultsStorage = userDefaultsStorage
    }
}

extension EducationStoriesInteractor: EducationStoriesInteractorInput {
    func setup(with output: EducationStoriesInteractorOutput) {
        self.output = output
    }

    func didCloseStories() {
        userDefaultsStorage.set(
            value: false,
            for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
        )
    }
}
