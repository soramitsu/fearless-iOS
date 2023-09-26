import UIKit
import Photos

class GetPreinstalledWalletRouter: GetPreinstalledWalletRouterInput {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: ControllerBackedProtocol?) {}

    func presentImageGallery(
        from view: ControllerBackedProtocol?,
        delegate: ImageGalleryDelegate,
        pickerDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    ) {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == PHAuthorizationStatus.authorized {
                        self.presentGallery(from: view, pickerDelegate: pickerDelegate)
                    } else {
                        delegate.didFail(in: self, with: ImageGalleryError.accessDeniedNow)
                    }
                }
            }
        case .restricted:
            delegate.didFail(in: self, with: ImageGalleryError.accessRestricted)
        case .denied:
            delegate.didFail(in: self, with: ImageGalleryError.accessDeniedPreviously)
        default:
            presentGallery(from: view, pickerDelegate: pickerDelegate)
        }
    }

    private func presentGallery(
        from view: ControllerBackedProtocol?,
        pickerDelegate: UIImagePickerControllerDelegate & UINavigationControllerDelegate
    ) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = pickerDelegate

        view?.controller.present(
            imagePicker,
            animated: true,
            completion: nil
        )
    }
}

class NewUserGetPreinstalledWalletRouter: GetPreinstalledWalletRouter {
    override func proceed(from _: ControllerBackedProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }
}

class ExistingUserGetPreinstalledWalletRouter: GetPreinstalledWalletRouter {
    override func proceed(from view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }
}
