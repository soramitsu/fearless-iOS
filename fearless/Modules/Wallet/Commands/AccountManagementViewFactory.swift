import Foundation

enum AccountManagementViewFactory {
    static func createViewForSwitch() -> ControllerBackedProtocol? {
        WalletsManagmentAssembly.configureModule(
            shouldSaveSelected: true,
            moduleOutput: nil
        )?.view
    }
}
