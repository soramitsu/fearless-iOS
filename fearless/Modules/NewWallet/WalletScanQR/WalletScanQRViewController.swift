import UIKit
import SoraUI
import AVFoundation
import SoraFoundation

final class WalletScanQRViewController: UIViewController, ViewHolder, AdaptiveDesignable {
    private enum Constants {
        static let messageVisibilityDuration: TimeInterval = 5.0
        static let decreasingBottomFactor: CGFloat = 0.8

        static let cameraWindowSize: CGFloat = 225
        static let cameraWindowPositionX: CGFloat = 0.5
        static let cameraWindowPositionY: CGFloat = 0.47
    }

    typealias RootViewType = WalletScanQRViewLayout

    let presenter: WalletScanQRPresenterProtocol

    lazy var messageAppearanceAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()
    lazy var messageDissmisAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    private var showsUpload: Bool = true

    init(presenter: WalletScanQRPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletScanQRViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        configure()
    }

    deinit {
        invalidateMessageScheduling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        presenter.prepareDismiss()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.prepareAppearance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        presenter.handleDismiss()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        presenter.handleAppearance()
    }

    private func configure() {
        rootView.uploadButton.isHidden = !showsUpload

        setupLocalization()

        rootView.qrFrameView.windowSize = CGSize(
            width: Constants.cameraWindowSize,
            height: Constants.cameraWindowSize
        )

        rootView.qrFrameView.windowPosition = CGPoint(
            x: Constants.cameraWindowPositionX,
            y: Constants.cameraWindowPositionY
        )
        var windowSize = rootView.qrFrameView.windowSize
        windowSize.width *= designScaleRatio.width
        windowSize.height *= designScaleRatio.width
        rootView.qrFrameView.windowSize = windowSize

        rootView.uploadButton.addTarget(self, action: #selector(actionUpload), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.scanQrTitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.titleLabel.text = R.string.localizable.scanQrSubtitle(preferredLanguages: selectedLocale.rLanguages)
        rootView.uploadButton.imageWithTitleView?.title = R.string.localizable.scanQrUploadButtonTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func configureVideoLayer(with captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds

        rootView.qrFrameView.frameLayer = videoPreviewLayer
    }

    // MARK: Message Management

    private func scheduleMessageHide() {
        invalidateMessageScheduling()

        perform(#selector(hideMessage), with: true, afterDelay: Constants.messageVisibilityDuration)
    }

    private func invalidateMessageScheduling() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(hideMessage),
            object: true
        )
    }

    @objc private func hideMessage() {
        let block: () -> Void = { [weak self] in
            self?.rootView.messageLabel.alpha = 0.0
        }

        messageDissmisAnimator.animate(block: block, completionBlock: nil)
    }

    // MARK: Actions

    @IBAction private func actionUpload() {
        presenter.activateImport()
    }
}

extension WalletScanQRViewController: WalletScanQRViewProtocol {
    func didReceive(session: AVCaptureSession) {
        configureVideoLayer(with: session)
    }

    func present(message: String, animated: Bool) {
        rootView.messageLabel.text = message

        let block: () -> Void = { [weak self] in
            self?.rootView.messageLabel.alpha = 1.0
        }

        if animated {
            messageAppearanceAnimator.animate(block: block, completionBlock: nil)
        } else {
            block()
        }

        scheduleMessageHide()
    }
}

extension WalletScanQRViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.uploadButton.invalidateLayout()
            view.setNeedsLayout()
        }
    }
}
