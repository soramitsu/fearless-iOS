import UIKit
import SSFModels

typealias AllDoneModuleCreationResult = (view: AllDoneViewInput, input: AllDoneModuleInput)

protocol AllDoneViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: AllDoneViewModel)
    func didReceive(explorer: ChainModel.ExternalApiExplorer?)
}

protocol AllDoneViewOutput: AnyObject {
    func didLoad(view: AllDoneViewInput)
    func dismiss()
    func didCopyTapped()
    func presentationControllerWillDismiss()
    func subscanButtonDidTapped()
    func shareButtonDidTapped()
}

protocol AllDoneInteractorInput: AnyObject {
    func setup(with output: AllDoneInteractorOutput)
}

protocol AllDoneInteractorOutput: AnyObject {}

protocol AllDoneRouterInput: PresentDismissable, ApplicationStatusPresentable, SharingPresentable {
    func presentSubscan(from view: ControllerBackedProtocol?, url: URL)
}

protocol AllDoneModuleInput: AnyObject {}

protocol AllDoneModuleOutput: AnyObject {}
