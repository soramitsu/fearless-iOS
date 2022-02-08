import Foundation

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
}

protocol NodeSelectionInteractorOutputProtocol: AnyObject {
    func didReceive(chain: ChainModel)
}

protocol NodeSelectionWireframeProtocol: PresentDismissable {}
