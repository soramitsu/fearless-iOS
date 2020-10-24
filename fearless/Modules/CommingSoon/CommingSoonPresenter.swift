import Foundation

final class CommingSoonPresenter {
    weak var view: CommingSoonViewProtocol?
    var wireframe: CommingSoonWireframeProtocol!
    var interactor: CommingSoonInteractorInputProtocol!

    let applicationConfig: ApplicationConfigProtocol

    init(applicationConfig: ApplicationConfigProtocol) {
        self.applicationConfig = applicationConfig
    }
}

extension CommingSoonPresenter: CommingSoonPresenterProtocol {
    func setup() {}

    func activateDevStatus() {
        if let view = view {
            wireframe.showWeb(url: applicationConfig.devStatusURL, from: view, style: .automatic)
        }
    }
    func activateRoadmap() {
        if let view = view {
            wireframe.showWeb(url: applicationConfig.roadmapURL, from: view, style: .automatic)
        }
    }
}

extension CommingSoonPresenter: CommingSoonInteractorOutputProtocol {}
