import Foundation
import UIKit

protocol DocumentPickerPresentable {
    func presentSelectFilePicker(
        from view: ControllerBackedProtocol?,
        documentTypes: [DocumentType],
        delegate: UIDocumentPickerDelegate
    )
}

extension DocumentPickerPresentable {
    func presentSelectFilePicker(
        from view: ControllerBackedProtocol?,
        documentTypes: [DocumentType],
        delegate: UIDocumentPickerDelegate
    ) {
        let controller = UIDocumentPickerViewController(
            documentTypes: documentTypes.map(\.rawValue),
            in: .import
        )
        controller.delegate = delegate
        controller.allowsMultipleSelection = false
        controller.modalPresentationStyle = .formSheet
        view?.controller.navigationController?.present(
            controller,
            animated: true,
            completion: nil
        )
    }
}
