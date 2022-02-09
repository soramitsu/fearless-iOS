// import UIKit
// protocol CheckPincodePresentable {
//    func presentCheckPincode(
//        from view: ControllerBackedProtocol,
//        output: CheckPincodeModuleOutput
//    )
// }
//
// extension CheckPincodePresentable {
//    func presentCheckPincode(
//        from view: ControllerBackedProtocol,
//        output: CheckPincodeModuleOutput
//    ) {
//        presentCheckPincode(
//            from: view,
//            output: output,
//            targetModule: nil,
//            presentationStyle: .present
//        )
//    }
//
//    func presentCheckPincode(
//        from view: ControllerBackedProtocol,
//        output: CheckPincodeModuleOutput,
//        targetModule: UIViewController?,
//        presentationStyle: PresentationStyle
//    ) {
//        let checkPincodeViewController = CheckPincodeViewFactory.createView(
//            moduleOutput: output,
//            targetView: targetModule,
//            presentationStyle: presentationStyle
//        ).controller
//        switch presentationStyle {
//        case .present:
//            view.controller.present(checkPincodeViewController, animated: true, completion: nil)
//        case .push:
//            view.controller.navigationController?.pushViewController(checkPincodeViewController, animated: true)
//        }
//    }
// }
