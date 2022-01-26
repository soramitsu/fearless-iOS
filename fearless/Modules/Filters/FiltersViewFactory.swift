import Foundation

struct FiltersViewFactory {
    static func createView(filterItems: [BaseFilterItem], moduleOutput: FiltersModuleOutput?) -> FiltersViewProtocol? {
        let interactor = FiltersInteractor(filterItems: filterItems)
        let wireframe = FiltersWireframe()

        let viewModelFactory: FiltersViewModelFactoryProtocol = FiltersViewModelFactory()
        let presenter = FiltersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput
        )

        let view = FiltersViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
