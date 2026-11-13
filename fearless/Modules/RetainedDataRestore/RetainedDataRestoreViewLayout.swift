import UIKit

/// Emergency material stays in memory only and is never shown. The user picks a
/// password, the material is sealed into an encrypted file (see
/// `EmergencyWalletMaterialEncryptor`), and only that file is offered for sharing.
/// Everything is discarded as soon as the app becomes inactive, so neither the app
/// switcher snapshot nor a later visitor finds anything.
final class EmergencyWalletMaterialViewController: UIViewController {
    /// The shared file is encrypted, but it is still every stored secret. Keep it off
    /// the general pasteboard, which syncs to the user's other devices, and away from
    /// posting, printing and contact targets. Files, AirDrop and mail stay available
    /// so the user can still take it to a recovery tool.
    static let excludedShareActivities: [UIActivity.ActivityType] = [
        .copyToPasteboard,
        .print,
        .assignToContact,
        .addToReadingList,
        .saveToCameraRoll,
        .markupAsPDF,
        .postToFacebook,
        .postToTwitter,
        .postToWeibo,
        .postToTencentWeibo,
        .postToFlickr,
        .postToVimeo
    ]

    static let exportFileName = "fearless-emergency-recovery.json"

    private var material: EmergencyWalletMaterial?
    private let encryptor: EmergencyWalletMaterialEncrypting
    private var exportFile: URL?
    private var isEncrypting = false

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    let messageLabel = UILabel()
    let passwordField = UITextField()
    let confirmationField = UITextField()
    let statusLabel = UILabel()
    let createButton = UIButton(type: .system)

    init(
        material: EmergencyWalletMaterial,
        encryptor: EmergencyWalletMaterialEncrypting = EmergencyWalletMaterialEncryptor()
    ) {
        self.material = material
        self.encryptor = encryptor
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = RecoveryText.string("export")
        view.backgroundColor = .systemBackground
        setupLayout()
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("close"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(redact),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.text = RecoveryText.string("export_warning") + "\n\n" + summary()

        for (field, placeholder) in [
            (passwordField, RecoveryText.string("export_password")),
            (confirmationField, RecoveryText.string("export_password_repeat"))
        ] {
            field.isSecureTextEntry = true
            // No strong-password suggestion: it would store this file's password in a
            // synced password manager, and its system sheet makes the screen lock itself.
            field.textContentType = nil
            field.passwordRules = nil
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.spellCheckingType = .no
            field.borderStyle = .roundedRect
            field.placeholder = placeholder
            field.font = .preferredFont(forTextStyle: .body)
            field.adjustsFontForContentSizeCategory = true
        }

        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel

        createButton.setTitle(RecoveryText.string("export_create"), for: .normal)
        createButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        createButton.titleLabel?.adjustsFontForContentSizeCategory = true
        createButton.addTarget(self, action: #selector(createEncryptedFile), for: .touchUpInside)

        [messageLabel, passwordField, confirmationField, statusLabel, createButton].forEach {
            stackView.addArrangedSubview($0)
        }

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            passwordField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            confirmationField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            createButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func summary() -> String {
        guard let material else { return "" }
        return String(
            format: RecoveryText.string("export_summary"),
            material.records.count,
            material.unreadableTags.count
        )
    }

    @objc func createEncryptedFile() {
        guard let material, !isEncrypting else { return }

        let password = passwordField.text ?? ""
        guard EmergencyWalletMaterialEncryptor.isAcceptablePassword(password) else {
            statusLabel.text = RecoveryText.string("export_password_short")
            return
        }
        guard password == confirmationField.text else {
            statusLabel.text = RecoveryText.string("export_password_mismatch")
            return
        }

        isEncrypting = true
        createButton.isEnabled = false
        statusLabel.text = nil
        passwordField.text = nil
        confirmationField.text = nil
        view.endEditing(true)

        let encryptor = self.encryptor
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { () -> URL in
                let file = try encryptor.encrypt(material, password: password)
                return try SensitiveExportFiles.write(file, fileName: Self.exportFileName)
            }

            DispatchQueue.main.async {
                guard let self else {
                    if case let .success(url) = result {
                        SensitiveExportFiles.remove(url)
                    }
                    return
                }
                self.finishEncryption(result)
            }
        }
    }

    private func finishEncryption(_ result: Result<URL, Error>) {
        isEncrypting = false

        guard material != nil else {
            // The screen locked while the file was being sealed.
            if case let .success(url) = result {
                SensitiveExportFiles.remove(url)
            }
            return
        }

        switch result {
        case let .success(url):
            removeExportFile()
            exportFile = url
            statusLabel.text = RecoveryText.string("export_ready")
            createButton.isEnabled = true
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: RecoveryText.string("share"),
                style: .plain,
                target: self,
                action: #selector(share)
            )
            share()
        case .failure:
            statusLabel.text = RecoveryText.string("export_failed")
            createButton.isEnabled = true
        }
    }

    @objc private func redact() {
        material = nil
        removeExportFile()
        passwordField.text = nil
        confirmationField.text = nil
        messageLabel.text = RecoveryText.string("locked")
        statusLabel.text = nil
        passwordField.isEnabled = false
        confirmationField.isEnabled = false
        createButton.isEnabled = false
        navigationItem.rightBarButtonItem = nil
        presentedViewController?.dismiss(animated: false)
    }

    @objc private func close() {
        redact()
        dismiss(animated: true)
    }

    @objc private func share() {
        guard material != nil, let exportFile else { return }
        let sheet = UIActivityViewController(activityItems: [exportFile], applicationActivities: nil)
        sheet.excludedActivityTypes = Self.excludedShareActivities
        sheet.completionWithItemsHandler = { [weak self] _, completed, _, _ in
            guard completed else { return }
            self?.removeExportFile()
            self?.navigationItem.rightBarButtonItem = nil
        }
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        anchorPopover(of: sheet)
        present(sheet, animated: true)
    }

    private func removeExportFile() {
        if let exportFile {
            SensitiveExportFiles.remove(exportFile)
        }
        exportFile = nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let exportFile {
            SensitiveExportFiles.remove(exportFile)
        }
    }
}
