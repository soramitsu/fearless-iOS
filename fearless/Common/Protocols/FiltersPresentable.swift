import Foundation

protocol FiltersPresentable {
    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        mode: FiltersMode,
        moduleOutput: FiltersModuleOutput?
    )
}

extension FiltersPresentable {
    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        mode: FiltersMode,
        moduleOutput: FiltersModuleOutput?
    ) {
        guard let view = view, let filtersViewController = FiltersViewFactory.createView(
            filters: filters,
            mode: mode,
            moduleOutput: moduleOutput
        )?.controller else {
            return
        }

        view.controller.present(filtersViewController, animated: true, completion: nil)
    }
}
