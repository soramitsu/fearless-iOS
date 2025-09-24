import UIKit
import SoraUI
import SoraFoundation
import AVFoundation

class ScanQRViewController: UIViewController, ViewHolder, AdaptiveDesignable, HiddableBarWhenPushed {
    private enum Constants {
        static let messageVisibilityDuration: TimeInterval = 5.0
        static let decreasingBottomFactor: CGFloat = 0.8

        static let cameraWindowSize: CGFloat = 225
        static let cameraWindowPositionX: CGFloat = 0.5
        static let cameraWindowPositionY: CGFloat = 0.47
    }

    typealias RootViewType = ScanQRViewLayout

    // MARK: Private properties

    private let output: ScanQRViewOutput
    private lazy var messageDissmisAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    // MARK: - Constructor

    init(
        output: ScanQRViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = ScanQRViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        configure()
        navigationController?.setNavigationBarHidden(true, animated: true)
    }

    deinit {
        invalidateMessageScheduling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        output.prepareDismiss()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        output.prepareAppearance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        output.handleDismiss()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        output.handleAppearance()
    }

    private func configure() {
        applyLocalization()

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

        rootView.addButton.addTarget(self, action: #selector(actionAdd), for: .touchUpInside)
        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(backButtonClicked),
            for: .touchUpInside
        )
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

    @objc private func actionAdd() {
        output.activateImport()
    }

    @objc private func backButtonClicked() {
        output.didTapBackButton()
    }

    // MARK: - Private methods
}

// MARK: - ScanQRViewInput

extension ScanQRViewController: ScanQRViewInput {
    func didReceive(session: AVCaptureSession) {
        configureVideoLayer(with: session)
    }

    func present(message: String, animated _: Bool) {
        DispatchQueue.main.async {
            self.rootView.messageLabel.text = message
            self.rootView.messageLabel.alpha = 1.0
            self.scheduleMessageHide()
        }
    }
}

// MARK: - Localizable

extension ScanQRViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
