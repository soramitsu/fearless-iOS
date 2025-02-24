import Foundation

final class CrossChainFundsPermissionRouter: CrossChainFundsPermissionRouterInput {
    func presentConfirm(
        crossChainSwapParameters: CrossChainSwapParameters,
        approveTxHash: String?,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainSwapConfirmAssembly.configureModule(
            crossChainSwapParameters: crossChainSwapParameters,
            approveTxHash: approveTxHash
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
        
        if let viewControllers = view?.controller.navigationController?.viewControllers, let controller = view?.controller {
            view?.controller.navigationController?.viewControllers =  viewControllers.filter { $0 != controller }
        }
    }
    
    func presentFundsPermission(
        mode: CrossChainFundsPermissionMode,
        crossChainSwapParameters: CrossChainSwapParameters,
        revokeTxHash: String?,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainFundsPermissionAssembly.configureModule(
            mode: mode,
            crossChainSwapParameters: crossChainSwapParameters,
            revokeTxHash: revokeTxHash
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
        
        if let viewControllers = view?.controller.navigationController?.viewControllers, let controller = view?.controller {
            view?.controller.navigationController?.viewControllers =  viewControllers.filter { $0 != controller }
        }
    }
}
