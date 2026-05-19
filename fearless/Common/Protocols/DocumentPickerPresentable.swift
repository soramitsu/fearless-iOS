import Foundation
import UIKit
import UniformTypeIdentifiers

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
        let contentTypes = documentTypes.map { UTType(importedAs: $0.rawValue) }
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
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
