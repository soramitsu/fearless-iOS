import Foundation
import SSFModels

protocol NodeSelectionViewProtocol: ControllerBackedProtocol {
    func didReceive(state: NodeSelectionViewState)
    func didReceive(locale: Locale)
}

protocol NodeSelectionPresenterProtocol: AnyObject {
    func setup()
    func didSelectNode(_ node: ChainNodeModel)
    func didChangeValueForAutomaticNodeSwitch(isOn: Bool)
    func didTapCloseButton()
    func didTapAddNodeButton()
}

protocol NodeSelectionInteractorInputProtocol: AnyObject {
    func setup()
    func selectNode(_ node: ChainNodeModel?)
    func setAutomaticSwitchNodes(_ automatic: Bool)
    func deleteNode(_ node: ChainNodeModel)

    var chain: ChainModel { get set }
}

protocol NodeSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(chain: ChainModel)
}

protocol NodeSelectionWireframeProtocol: PresentDismissable, SheetAlertPresentable {
    func presentAddNodeFlow(
        with chain: ChainModel,
        moduleOutput: AddCustomNodeModuleOutput?,
        from view: ControllerBackedProtocol?
    )

    func presentNodeInfo(
        chain: ChainModel,
        node: ChainNodeModel,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    )
}
