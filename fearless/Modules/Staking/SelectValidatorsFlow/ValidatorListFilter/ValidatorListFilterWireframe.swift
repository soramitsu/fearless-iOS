final class ValidatorListFilterWireframe: ValidatorListFilterWireframeProtocol {
    func close(_ view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
