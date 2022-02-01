import Foundation

protocol FiltersPresentable {
    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        moduleOutput: FiltersModuleOutput?
    )
}

extension FiltersPresentable {
    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        moduleOutput: FiltersModuleOutput?
    ) {
        guard let view = view, let filtersViewController = FiltersViewFactory.createView(
            filters: filters,
            moduleOutput: moduleOutput
        )?.controller else {
            return
        }

        view.controller.present(filtersViewController, animated: true, completion: nil)
    }
}
