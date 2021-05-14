import Foundation

protocol NetworkTypeSelectionPresentable {
    func presentNetworkTypeSelection(
        from view: ControllerBackedProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    )
}

extension NetworkTypeSelectionPresentable {
    func presentNetworkTypeSelection(
        from view: ControllerBackedProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(
            availableTypes,
            selectedType: selectedType,
            delegate: delegate,
            context: context
        ) else {
            return
        }

        view?.controller.present(
            modalPicker,
            animated: true,
            completion: nil
        )
    }
}
