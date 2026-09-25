import CryptoKit
import UIKit

struct IrohaConnectPrompt: Equatable {
    enum Kind: Equatable {
        case connection
        case signature(payload: Data)
    }

    let kind: Kind
    let appName: String
    let appURL: URL?
    let networkName: String
    let accountID: String

    var payloadDigest: String? {
        guard case let .signature(payload) = kind else {
            return nil
        }

        return SHA256.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    var payloadByteCount: Int? {
        guard case let .signature(payload) = kind else {
            return nil
        }

        return payload.count
    }

    static func shortenedAccountID(_ accountID: String) -> String {
        guard accountID.count > 24 else {
            return accountID
        }

        return "\(accountID.prefix(12))…\(accountID.suffix(10))"
    }
}

final class IrohaConnectSakuraView: UIView {
    private let emitter = CAEmitterLayer()
    private var staticPetals: [CAShapeLayer] = []
    private var isConfigured = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMotion),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window != nil, !isConfigured else {
            return
        }

        isConfigured = true
        updateMotion()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: -24)
        emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    @objc private func updateMotion() {
        emitter.removeFromSuperlayer()
        staticPetals.forEach { $0.removeFromSuperlayer() }
        staticPetals.removeAll()

        if UIAccessibility.isReduceMotionEnabled {
            installStaticPetals()
        } else {
            installEmitter()
        }
    }

    private func installEmitter() {
        emitter.emitterShape = .line
        emitter.emitterMode = .surface
        emitter.renderMode = .backToFront

        let petal = CAEmitterCell()
        petal.contents = Self.makePetalImage().cgImage
        petal.birthRate = 1.7
        petal.lifetime = 14
        petal.lifetimeRange = 5
        petal.velocity = 38
        petal.velocityRange = 22
        petal.emissionLongitude = .pi
        petal.emissionRange = .pi / 7
        petal.xAcceleration = 4
        petal.yAcceleration = 7
        petal.spin = 0.8
        petal.spinRange = 1.8
        petal.scale = 0.24
        petal.scaleRange = 0.12
        petal.alphaSpeed = -0.025
        emitter.emitterCells = [petal]
        layer.addSublayer(emitter)
    }

    private func installStaticPetals() {
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0.10, 0.12, -0.3),
            (0.82, 0.09, 0.5),
            (0.70, 0.34, -0.8),
            (0.18, 0.52, 0.9),
            (0.88, 0.70, -0.1),
            (0.32, 0.82, 0.4)
        ]

        staticPetals = positions.map { position in
            let petal = CAShapeLayer()
            petal.path = Self.petalPath(size: 12).cgPath
            petal.fillColor = UIColor(red: 0.98, green: 0.63, blue: 0.78, alpha: 0.45).cgColor
            petal.position = CGPoint(x: bounds.width * position.0, y: bounds.height * position.1)
            petal.setAffineTransform(CGAffineTransform(rotationAngle: position.2))
            layer.addSublayer(petal)
            return petal
        }
    }

    private static func makePetalImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 44))
        return renderer.image { context in
            context.cgContext.translateBy(x: 16, y: 20)
            UIColor(red: 0.98, green: 0.64, blue: 0.79, alpha: 0.9).setFill()
            context.cgContext.addPath(petalPath(size: 14).cgPath)
            context.cgContext.fillPath()
        }
    }

    private static func petalPath(size: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: -size))
        path.addCurve(
            to: CGPoint(x: size * 0.38, y: size * 0.86),
            controlPoint1: CGPoint(x: size * 0.9, y: -size * 0.8),
            controlPoint2: CGPoint(x: size * 0.9, y: size * 0.32)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: size * 1.12),
            controlPoint1: CGPoint(x: size * 0.18, y: size),
            controlPoint2: CGPoint(x: size * 0.05, y: size * 1.1)
        )
        path.addCurve(
            to: CGPoint(x: -size * 0.38, y: size * 0.86),
            controlPoint1: CGPoint(x: -size * 0.05, y: size * 1.1),
            controlPoint2: CGPoint(x: -size * 0.2, y: size)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -size),
            controlPoint1: CGPoint(x: -size * 0.9, y: size * 0.32),
            controlPoint2: CGPoint(x: -size * 0.9, y: -size * 0.8)
        )
        path.close()
        return path
    }
}

private final class IrohaConnectBackgroundView: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [
            UIColor(red: 0.07, green: 0.04, blue: 0.09, alpha: 1).cgColor,
            UIColor(red: 0.15, green: 0.05, blue: 0.12, alpha: 1).cgColor,
            UIColor.black.cgColor
        ]
        gradient.locations = [0, 0.55, 1]
        layer.insertSublayer(gradient, at: 0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

final class IrohaConnectPromptViewController: UIViewController, ControllerBackedProtocol {
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    private let prompt: IrohaConnectPrompt
    private let approveButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)

    init(prompt: IrohaConnectPrompt) {
        self.prompt = prompt
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = IrohaConnectBackgroundView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
    }

    func setActionsEnabled(_ isEnabled: Bool) {
        approveButton.isEnabled = isEnabled
        rejectButton.isEnabled = isEnabled
    }

    private func buildLayout() {
        let sakura = IrohaConnectSakuraView()
        sakura.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sakura)

        let eyebrow = makeLabel(text: "IROHA CONNECT", style: .caption1, weight: .semibold)
        eyebrow.textColor = UIColor(red: 1, green: 0.66, blue: 0.82, alpha: 1)
        eyebrow.accessibilityTraits.insert(.header)

        let isSignature = prompt.payloadDigest != nil
        let title = makeLabel(
            text: isSignature ? "Approve contract signature" : "Connect your SORA wallet",
            style: .largeTitle,
            weight: .bold
        )
        title.numberOfLines = 0
        title.accessibilityTraits.insert(.header)

        let explanation = makeLabel(
            text: isSignature
                ? "Review this request before Fearless signs it with your selected Iroha account."
                : "A SORA dApp wants to use your public account and request signatures. " +
                "Your recovery phrase and private key never leave Fearless.",
            style: .body,
            weight: .regular
        )
        explanation.numberOfLines = 0
        explanation.textColor = UIColor.white.withAlphaComponent(0.72)

        let details = UIStackView(arrangedSubviews: detailRows())
        details.axis = .vertical
        details.spacing = 12
        details.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        details.isLayoutMarginsRelativeArrangement = true
        details.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        details.layer.cornerRadius = 18

        configurePrimaryButton(isSignature: isSignature)
        configureSecondaryButton()

        let stack = UIStackView(arrangedSubviews: [
            eyebrow,
            title,
            explanation,
            details,
            approveButton,
            rejectButton
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.setCustomSpacing(8, after: eyebrow)
        stack.setCustomSpacing(28, after: explanation)
        stack.setCustomSpacing(28, after: details)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            sakura.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sakura.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sakura.topAnchor.constraint(equalTo: view.topAnchor),
            sakura.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 34),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            approveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            rejectButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    private func detailRows() -> [UIView] {
        var rows = [
            makeDetailRow(label: "APP CLAIM", value: prompt.appName),
            makeDetailRow(label: "NETWORK", value: prompt.networkName),
            makeDetailRow(label: "ACCOUNT", value: IrohaConnectPrompt.shortenedAccountID(prompt.accountID)),
            makeDetailRow(label: "PERMISSION", value: "Sign Uranai contract calls only")
        ]

        if let appURL = prompt.appURL {
            rows.insert(
                makeDetailRow(label: "CLAIMED ORIGIN", value: appURL.host ?? appURL.absoluteString),
                at: 1
            )
        }
        if let byteCount = prompt.payloadByteCount, let digest = prompt.payloadDigest {
            rows.append(makeDetailRow(label: "PAYLOAD", value: "\(byteCount) bytes"))
            rows.append(makeDetailRow(label: "SHA-256", value: "\(digest.prefix(16))…\(digest.suffix(12))"))
        }

        return rows
    }

    private func makeDetailRow(label: String, value: String) -> UIView {
        let key = makeLabel(text: label, style: .caption2, weight: .semibold)
        key.textColor = UIColor.white.withAlphaComponent(0.48)
        key.setContentCompressionResistancePriority(.required, for: .horizontal)

        let detail = makeLabel(text: value, style: .subheadline, weight: .medium)
        detail.numberOfLines = 2
        detail.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [key, detail])
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 12
        row.accessibilityLabel = "\(label), \(value)"
        return row
    }

    private func configurePrimaryButton(isSignature: Bool) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = isSignature ? "Review with PIN" : "Connect with PIN"
        configuration.baseBackgroundColor = UIColor(red: 0.95, green: 0.26, blue: 0.58, alpha: 1)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        approveButton.configuration = configuration
        approveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        approveButton.addTarget(self, action: #selector(approve), for: .touchUpInside)
        approveButton.accessibilityHint = "Opens wallet authorization before any signature is created."
    }

    private func configureSecondaryButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Reject"
        configuration.baseForegroundColor = UIColor.white.withAlphaComponent(0.8)
        rejectButton.configuration = configuration
        rejectButton.addTarget(self, action: #selector(reject), for: .touchUpInside)
        rejectButton.accessibilityHint = "Closes this IrohaConnect request without signing."
    }

    private func makeLabel(text: String, style: UIFont.TextStyle, weight: UIFont.Weight) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(
            for: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
        )
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    @objc private func approve() {
        approveButton.isEnabled = false
        rejectButton.isEnabled = false
        onApprove?()
    }

    @objc private func reject() {
        onReject?()
    }
}

final class IrohaConnectLandingViewController: UIViewController, ControllerBackedProtocol {
    var onScan: (() -> Void)?
    var onPaste: (() -> Void)?
    var onClose: (() -> Void)?

    override func loadView() {
        view = IrohaConnectBackgroundView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "IrohaConnect"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )
        buildLayout()
    }

    private func buildLayout() {
        let sakura = IrohaConnectSakuraView()
        sakura.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sakura)

        let mark = UILabel()
        mark.text = "桜"
        mark.textAlignment = .center
        mark.textColor = UIColor(red: 1, green: 0.68, blue: 0.83, alpha: 1)
        mark.font = .systemFont(ofSize: 64, weight: .ultraLight)
        mark.accessibilityLabel = "Sakura"

        let title = UILabel()
        title.text = "Connect to SORA dApps"
        title.textColor = .white
        title.textAlignment = .center
        title.numberOfLines = 0
        title.font = .preferredFont(forTextStyle: .title1)
        title.adjustsFontForContentSizeCategory = true
        title.accessibilityTraits.insert(.header)

        let body = UILabel()
        body.text = "In Uranai or another compatible app, choose IrohaConnect. " +
            "Open the pairing link on this iPhone, scan its QR code, or paste the link here. " +
            "Every signature still needs your approval."
        body.textColor = UIColor.white.withAlphaComponent(0.72)
        body.textAlignment = .center
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        body.adjustsFontForContentSizeCategory = true

        let scanButton = makeActionButton(
            title: "Scan pairing QR",
            image: "qrcode.viewfinder",
            selector: #selector(scan)
        )
        let pasteButton = makeActionButton(
            title: "Paste pairing link",
            image: "doc.on.clipboard",
            selector: #selector(pasteConnectionURI)
        )
        pasteButton.configuration?.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)

        let safety = UILabel()
        safety.text = "Fearless accepts only the canonical Taira endpoint and Uranai’s scoped " +
            "contract-signing permission. Private keys remain in Keychain-backed wallet storage."
        safety.textColor = UIColor.white.withAlphaComponent(0.52)
        safety.textAlignment = .center
        safety.numberOfLines = 0
        safety.font = .preferredFont(forTextStyle: .footnote)
        safety.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [mark, title, body, scanButton, pasteButton, safety])
        stack.axis = NSLayoutConstraint.Axis.vertical
        stack.spacing = 18
        stack.setCustomSpacing(30, after: body)
        stack.setCustomSpacing(28, after: pasteButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            sakura.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sakura.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sakura.topAnchor.constraint(equalTo: view.topAnchor),
            sakura.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            scanButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            pasteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])
    }

    private func makeActionButton(title: String, image: String, selector: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: image)
        configuration.imagePadding = 10
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor(red: 0.95, green: 0.26, blue: 0.58, alpha: 1)
        configuration.cornerStyle = .large
        button.configuration = configuration
        button.addTarget(self, action: selector, for: .touchUpInside)
        return button
    }

    @objc private func scan() {
        onScan?()
    }

    @objc private func pasteConnectionURI() {
        onPaste?()
    }

    @objc private func close() {
        onClose?()
    }
}
