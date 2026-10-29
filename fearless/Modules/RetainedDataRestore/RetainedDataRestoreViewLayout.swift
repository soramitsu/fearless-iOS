import UIKit

/// Emergency material stays in memory only. The preview is discarded as soon as
/// the app becomes inactive, so the app switcher never receives a secret snapshot.
final class EmergencyWalletMaterialViewController: UIViewController {
    /// The material is every stored secret in plain text. The share sheet keeps it off
    /// the general pasteboard, which syncs to the user's other devices, and away from
    /// posting, printing and contact targets. Files, AirDrop and mail stay available so
    /// the user can still take it to a recovery tool.
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

    private var material: EmergencyWalletMaterial?
    private let textView = UITextView()

    init(material: EmergencyWalletMaterial) {
        self.material = material
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
        textView.isEditable = false
        textView.isSelectable = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = RecoveryText.string("export_warning") + "\n\n" + encodedMaterial()
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("close"),
            style: .plain,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: RecoveryText.string("share"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(redact),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    private func encodedMaterial() -> String {
        guard let material else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(material) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    @objc private func redact() {
        material = nil
        textView.text = RecoveryText.string("locked")
        navigationItem.rightBarButtonItem = nil
    }

    @objc private func close() {
        redact()
        dismiss(animated: true)
    }

    @objc private func share() {
        guard material != nil else { return }
        let sheet = UIActivityViewController(activityItems: [encodedMaterial()], applicationActivities: nil)
        sheet.excludedActivityTypes = Self.excludedShareActivities
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        anchorPopover(of: sheet)
        present(sheet, animated: true)
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
