import UIKit

protocol ImageGalleryDelegate: AnyObject {
    func didCompleteImageSelection(
        from gallery: ImageGalleryPresentable,
        with selectedImages: [UIImage]
    )
    func didFail(
        in gallery: ImageGalleryPresentable,
        with error: Error
    )
}

enum ImageGalleryError: Error {
    case accessDeniedPreviously
    case accessDeniedNow
    case accessRestricted
    case unknownAuthorizationStatus
}

protocol ImageGalleryPresentable: AnyObject {
    func presentImageGallery(
        from view: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate,
        pickerDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    )
}
