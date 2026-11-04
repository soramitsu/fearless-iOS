import UIKit

/// The group Hide confirmation owns its layout in the presenting window's bounds.
/// Its content and Cancel action scroll independently of the fixed close control.
final class PortfolioGroupHideViewController: UIViewController {
    let scrollView = UIScrollView()
    let titleLabel = UILabel()
    let messageLabel = UILabel()
    let confirmButton = PortfolioActionButton()
    let cancelButton = PortfolioActionButton()
    let closeButton = UIButton(type: .system)

    private let viewModel: SheetAlertPresentableViewModel
    private let panel = UIView()
    private let panelMask = CAShapeLayer()
    private var panelPlacement: AdaptivePanelPlacement?
    private var finished = false

    init(viewModel: SheetAlertPresentableViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityViewIsModal = true
        let backdrop = UIControl()
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        backdrop.isAccessibilityElement = false
        backdrop.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        panel.backgroundColor = UIColor(named: "fwSurfaceRaised")
        panel.layer.mask = panelMask
        for child in [backdrop, panel] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
        }
        for child in [closeButton, scrollView] {
            child.translatesAutoresizingMaskIntoConstraints = false
            panel.addSubview(child)
        }
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, confirmButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        configureContent()
        constrainContent(stack: stack, backdrop: backdrop)
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self]
            ) { (controller: PortfolioGroupHideViewController, _: UITraitCollection) in
                controller.updateFonts()
            }
        }
        updateFonts()
    }

    private func configureContent() {
        titleLabel.text = viewModel.title
        titleLabel.accessibilityTraits.insert(.header)
        messageLabel.text = viewModel.message
        messageLabel.isHidden = viewModel.message == nil
        for label in [titleLabel, messageLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        titleLabel.textColor = UIColor(named: "fwTextPrimary")
        messageLabel.textColor = UIColor(named: "fwTextSecondary")
        confirmButton.configuration?.title = viewModel.actions.first?.title
        confirmButton.configuration?.background.backgroundColor = UIColor(named: "fwFillTop")
        confirmButton.configuration?.baseForegroundColor = UIColor(named: "fwTextOnAccent")
        confirmButton.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        cancelButton.configuration?.title = viewModel.closeAction
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(named: "fwTextPrimary")
        closeButton.accessibilityLabel = viewModel.closeAction
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        for button in [confirmButton, cancelButton] {
            button.setContentCompressionResistancePriority(.required, for: .vertical)
        }
    }

    private func constrainContent(stack: UIStackView, backdrop: UIView) {
        let contentHeight = scrollView.heightAnchor.constraint(equalTo: stack.heightAnchor)
        contentHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            closeButton.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            confirmButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            contentHeight
        ])
        let placement = AdaptivePanelPlacement(panel: panel, in: view, compact: [
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
        placement.update(for: traitCollection)
        panelPlacement = placement
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFonts()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        panelPlacement?.update(for: traitCollection)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        panelMask.path = FWChamferPath.path(in: panel.bounds).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) {
            return
        }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            updateFonts()
        }
    }

    private func updateFonts() {
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2, compatibleWith: traitCollection)
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
    }

    @objc private func confirm() {
        guard !finished else { return }
        finished = true
        confirmButton.isEnabled = false
        let handler = viewModel.actions.first?.handler
        dismiss(animated: true) { handler?() }
    }

    @objc private func cancel() {
        guard !finished else { return }
        finished = true
        dismiss(animated: true)
    }

    override func accessibilityPerformEscape() -> Bool {
        cancel()
        return true
    }
}
