import SoraFoundation
import SSFModels
import UIKit

/// A text view for a recovery phrase: no autocorrect, spelling, prediction, smart punctuation,
/// writing tools, shortcuts bar, paste, copy or cut. The words go nowhere but this view.
final class RecoveryPhraseTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        keyboardType = .asciiCapable
        textContentType = nil
        pasteConfiguration = nil
        if #available(iOS 17.0, *) {
            inlinePredictionType = .no
        }
        #if compiler(>=6.0)
            if #available(iOS 18.0, *) {
                writingToolsBehavior = .none
            }
        #endif
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let blocked: [Selector] = [
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.copy(_:)),
            #selector(UIResponderStandardEditActions.cut(_:)),
            #selector(UIResponderStandardEditActions.pasteAndMatchStyle(_:))
        ]
        if blocked.contains(action) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_: Any?) {}
    override func copy(_: Any?) {}
    override func cut(_: Any?) {}
}

/// One press of Check. Closing the screen cancels it: a check still deriving keys then records
/// nothing.
final class RecoveryCheckAttempt {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

/// Step 2 of 3 of the recovery check: type the phrase from the backup. A match records recovery
/// evidence and starts the move (the system sheet follows); a mismatch changes nothing.
final class ProtectedKeychainRecoveryCheckViewController: UIViewController, ControllerBackedProtocol {
    private let wallet: MetaAccountModel
    private let check: ProtectedKeychainRecoveryCheck
    private let locale: Locale
    private let onVerified: () -> Void
    private let workQueue: DispatchQueue
    private let isScreenCaptured: (UIViewController) -> Bool
    private(set) var attempt: RecoveryCheckAttempt?

    private lazy var captureGuard = SecretCaptureGuard(
        owner: self,
        languages: { [weak self] in self?.locale.rLanguages },
        isCaptured: isScreenCaptured
    )

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let phraseView: RecoveryPhraseTextView = {
        let view = RecoveryPhraseTextView(frame: .zero, textContainer: nil)
        view.font = .p1Paragraph
        view.textColor = R.color.colorWhite()
        view.tintColor = R.color.colorWhite()
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        return view
    }()

    let phraseContainer: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorBlack()!
        view.highlightedFillColor = R.color.colorBlack()!
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = 1
        return view
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.numberOfLines = 0
        return label
    }()

    let checkButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(R.color.colorLightGray(), for: .normal)
        return button
    }()

    init(
        wallet: MetaAccountModel,
        check: ProtectedKeychainRecoveryCheck = .shared,
        locale: Locale,
        workQueue: DispatchQueue = .global(qos: .userInitiated),
        isScreenCaptured: @escaping (UIViewController) -> Bool = SecretCaptureGuard.isScreenCaptured,
        onVerified: @escaping () -> Void
    ) {
        self.wallet = wallet
        self.check = check
        self.locale = locale
        self.workQueue = workQueue
        self.isScreenCaptured = isScreenCaptured
        self.onVerified = onVerified
        super.init(nibName: nil, bundle: nil)
        isModalInPresentation = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.colorBlack()
        layout()
        let languages = locale.rLanguages
        titleLabel.text = R.string.localizable.protectedRecoveryCheckTitle(preferredLanguages: languages)
        messageLabel.text = R.string.localizable.protectedRecoveryCheckHint(preferredLanguages: languages)
        checkButton.imageWithTitleView?.title = R.string.localizable.protectedRecoveryCheckAction(preferredLanguages: languages)
        closeButton.setTitle(R.string.localizable.protectedRecoveryLater(preferredLanguages: languages), for: .normal)
        // Selected words never leave by drag and drop either.
        phraseView.textDragInteraction?.isEnabled = false
        checkButton.addTarget(self, action: #selector(didTapCheck), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        captureGuard.protect([phraseContainer])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureGuard.start()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // While the screen is recorded the field is covered and the keyboard stays down: key
        // previews would show the words.
        if !isScreenCaptured(self) {
            phraseView.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureGuard.stop()
        // A check still running when the screen goes records nothing, and the words never outlive it.
        attempt?.cancel()
        phraseView.text = ""
    }

    private func layout() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, phraseContainer, statusLabel, checkButton, closeButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        phraseView.translatesAutoresizingMaskIntoConstraints = false
        phraseContainer.addSubview(phraseView)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            phraseView.topAnchor.constraint(equalTo: phraseContainer.topAnchor, constant: 8),
            phraseView.bottomAnchor.constraint(equalTo: phraseContainer.bottomAnchor, constant: -8),
            phraseView.leadingAnchor.constraint(equalTo: phraseContainer.leadingAnchor, constant: 12),
            phraseView.trailingAnchor.constraint(equalTo: phraseContainer.trailingAnchor, constant: -12),
            phraseContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            checkButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc func didTapCheck() {
        guard attempt == nil else {
            return
        }
        let phrase = phraseView.text ?? ""
        let attempt = RecoveryCheckAttempt()
        self.attempt = attempt
        checkButton.applyDisabledStyle()
        let check = self.check
        let wallet = self.wallet
        workQueue.async { [weak self] in
            let outcome = check.verify(phrase: phrase, wallet: wallet, isCancelled: { attempt.isCancelled })
            DispatchQueue.main.async {
                self?.finish(attempt, outcome: outcome)
            }
        }
    }

    @objc func didTapClose() {
        // Closing changes nothing: the wallet stays as it is.
        attempt?.cancel()
        dismiss(animated: true)
    }

    private func finish(_ finished: RecoveryCheckAttempt, outcome: ProtectedKeychainRecoveryCheck.Outcome) {
        guard finished === attempt else {
            return
        }
        attempt = nil
        // A cancelled swipe-to-close keeps the screen; the check it cancelled recorded nothing.
        guard !finished.isCancelled else {
            checkButton.applyEnabledStyle()
            return
        }
        show(outcome)
    }

    func show(_ outcome: ProtectedKeychainRecoveryCheck.Outcome) {
        let languages = locale.rLanguages
        switch outcome {
        case .verified:
            phraseView.text = ""
            dismiss(animated: true) { [onVerified] in onVerified() }
        case .mismatch:
            checkButton.applyEnabledStyle()
            statusLabel.textColor = R.color.colorRed()
            statusLabel.text = R.string.localizable.protectedRecoveryCheckMismatch(preferredLanguages: languages)
        case .customPath, .unavailable:
            phraseView.text = ""
            phraseView.isEditable = false
            statusLabel.textColor = R.color.colorLightGray()
            statusLabel.text = R.string.localizable.protectedRecoveryCheckStays(preferredLanguages: languages)
            checkButton.isHidden = true
            closeButton.setTitle(R.string.localizable.commonClose(preferredLanguages: languages), for: .normal)
        }
    }
}

extension SheetAlertPresentableViewModel {
    /// Step 1 of 3: one action, one warning. Showing it is the one offer for this wallet.
    static func protectedRecoveryCheckOffer(
        locale: Locale,
        onCheck: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        let languages = locale.rLanguages
        let check = SheetAlertPresentableAction(
            title: R.string.localizable.protectedRecoveryOfferAction(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) {
            onCheck()
        }
        return SheetAlertPresentableViewModel(
            title: R.string.localizable.protectedRecoveryOfferTitle(preferredLanguages: languages),
            message: R.string.localizable.protectedRecoveryOfferMessage(preferredLanguages: languages),
            actions: [check],
            closeAction: R.string.localizable.protectedRecoveryLater(preferredLanguages: languages),
            dismissCompletion: onClose,
            icon: R.image.iconWarningBig()
        )
    }
}
