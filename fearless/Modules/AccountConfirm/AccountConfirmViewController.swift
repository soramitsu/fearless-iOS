import AudioToolbox
import SoraFoundation
import SoraUI
import UIKit

final class AccountConfirmViewController: UIViewController, AdaptiveDesignable {
    private enum Constants {
        static let externalMargin: CGFloat = 16.0
        static let itemsSpacing: CGFloat = 8.0
        static let internalMargin: CGFloat = 16.0
        static let itemContentInsets = UIEdgeInsets(
            top: 13.0,
            left: 11.0,
            bottom: 13.0,
            right: 11.0
        )
        static let cornerRadius: CGFloat = 4.0
    }

    private struct Position {
        let leading: NSLayoutConstraint
        let top: NSLayoutConstraint
    }

    var presenter: AccountConfirmPresenterProtocol!
    /// Significant-spacing presentation for legacy TON export confirmation.
    var showsExactMnemonicSpacing = false

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var bottomPlaneView: UIView!
    @IBOutlet private var topPlaneView: UIView!

    @IBOutlet private var buttonsView: UIView!
    @IBOutlet private var buttonsHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var nextButton: TriangularedButton!
    @IBOutlet private var skipButton: TriangularedButton?

    @IBOutlet private var topPlaneHeight: NSLayoutConstraint!
    @IBOutlet private var bottomPlaneHeight: NSLayoutConstraint!

    private var minHeight: CGFloat = 0.0

    var wordTransitionAnimation = BlockViewAnimator(
        duration: 0.25,
        options: [.curveEaseOut]
    )

    var retryAnimation = TransitionAnimator(
        type: .fade,
        duration: 0.25
    )

    var wrongSequenceAnimation = ShakeAnimator(
        duration: 0.5,
        options: [.curveEaseInOut]
    )

    private var contentWidth: CGFloat = 0.0
    private var adaptiveLayout: AccountConfirmAdaptiveLayout?
    private var legacyHeadingLabel: UILabel?
    private var orderedButtons: [RoundedButton] = []
    // Display labels are never used as secret material, including after a locale change.
    private var wordValues: [RoundedButton: String] = [:]
    private var needsAdaptiveReflow = false
    private var needsTypographyRefresh = false

    private var selectedLocale: Locale {
        localizationManager?.selectedLocale ?? .current
    }

    private var pendingButtons: [RoundedButton] = []
    private var submittedButtons: [RoundedButton] = []
    private var positions: [RoundedButton: Position] = [:]
    private var originalPositions: [RoundedButton: Position] = [:]

    lazy var nextButtonTitle: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
    }

    var skipButtonTitle: LocalizableResource<String>?

    override func viewDidLoad() {
        super.viewDidLoad()

        if FWAppearance.accountConfirmRestyled {
            adaptiveLayout = AccountConfirmAdaptiveLayout(
                root: view, scroll: scrollView, content: contentView, top: topPlaneView,
                bottom: bottomPlaneView, actions: buttonsView, next: nextButton,
                actionsHeight: buttonsHeightConstraint
            )
            navigationItem.titleView = UIView()
        } else {
            setupLegacyHeading()
        }
        if skipButtonTitle != nil {
            createSkipButton()
        }
        if adaptiveLayout == nil {
            // Preserve the fixed-bottom legacy footer while allowing each full title to grow.
            buttonsHeightConstraint.isActive = false
            [nextButton, skipButton].compactMap { $0 }.forEach { button in
                button.constraints.filter { $0.firstAttribute == .height && $0.secondItem == nil }
                    .forEach { $0.isActive = false }
            }
            (skipButton ?? nextButton).topAnchor.constraint(equalTo: buttonsView.topAnchor).isActive = true
        }

        setupNavigationItem()
        setupLocalization()
        configureLayout()
        updateNextButton()

        presenter.didLoad(view: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if needsTypographyRefresh {
            needsTypographyRefresh = false
            refreshAdaptiveTypography()
        }
        // Match the XIB's safe-area-width-minus-margins constraint before its child layout pass.
        let width = view.bounds.inset(by: view.safeAreaInsets).width - 2 * Constants.externalMargin
        guard width > 0 else { return }
        if abs(contentWidth - width) > 0.5 || needsAdaptiveReflow {
            contentWidth = width
            needsAdaptiveReflow = false
            reflowWordButtons()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard isViewLoaded else { return }
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory ||
            previousTraitCollection?.legibilityWeight != traitCollection.legibilityWeight {
            // UIKit may still be propagating Bold Text while this callback runs on iOS 18.
            // Resolve fonts and reflow together after the view hierarchy receives its traits.
            needsTypographyRefresh = true
            view.setNeedsLayout()
        }
    }

    private func configureLayout() {
        contentWidth = view.bounds.inset(by: view.safeAreaInsets).width - 2 * Constants.externalMargin
    }

    private func reflowWordButtons() {
        orderedButtons.compactMap { $0 as? AccountConfirmWordButton }.forEach {
            $0.maximumWidth = max(1, contentWidth - 2 * Constants.internalMargin)
        }
        for position in Array(positions.values) + Array(originalPositions.values) {
            position.leading.isActive = false
            position.top.isActive = false
        }
        positions = [:]
        originalPositions = [:]
        // Preserve the initial choice order and its empty slots while selected words move above.
        let rows = createRowsFromButtons(orderedButtons)
        bottomPlaneHeight.constant = max(44, layoutRows(rows, on: bottomPlaneView)) + 2 * Constants.internalMargin
        originalPositions = positions
        minHeight = adaptiveLayout == nil ? bottomPlaneHeight.constant : 44 + 2 * Constants.internalMargin
        layoutSubmittedButtons()
    }

    private func setupLocalization() {
        guard let locale = localizationManager?.selectedLocale else {
            return
        }

        title = R.string.localizable.accountConfirmationTitle(preferredLanguages: locale.rLanguages)
        navigationItem.rightBarButtonItem?.customView?.accessibilityLabel = R.string.localizable.commonReset(
            preferredLanguages: locale.rLanguages
        )

        detailsLabel.text = showsExactMnemonicSpacing
            ? R.string.localizable.confirmationExactDetails(preferredLanguages: locale.rLanguages)
            : R.string.localizable.accountConfirmationDetails(preferredLanguages: locale.rLanguages)
        for (button, word) in wordValues {
            button.imageWithTitleView?.title = displayTitle(for: word)
            button.accessibilityLabel = button.imageWithTitleView?.title
        }

        nextButton.imageWithTitleView?.title = nextButtonTitle.value(for: locale)
        nextButton.invalidateLayout()

        skipButton?.imageWithTitleView?.title = skipButtonTitle?.value(for: locale)
        refreshAdaptiveTypography()
    }

    private func createButton() -> RoundedButton {
        let button = AccountConfirmWordButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.contentInsets = Constants.itemContentInsets
        button.roundedBackgroundView?.fillColor = R.color.colorPink()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorHighlightedAccent()!
        button.roundedBackgroundView?.cornerRadius = Constants.cornerRadius
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        button.imageWithTitleView?.titleFont = UIFont.p1Paragraph
        button.changesContentOpacityWhenHighlighted = true

        button.addTarget(
            self,
            action: #selector(actionItem),
            for: .touchUpInside
        )

        return button
    }

    private func apply(words: [String]) {
        clearButtons()

        let newPendingButtons: [RoundedButton] = words.map { word in
            let button = createButton()
            wordValues[button] = word
            button.imageWithTitleView?.title = displayTitle(for: word)
            button.accessibilityLabel = button.imageWithTitleView?.title
            return button
        }

        newPendingButtons.forEach { contentView.addSubview($0) }

        pendingButtons = newPendingButtons
        orderedButtons = newPendingButtons

        refreshAdaptiveTypography()
        reflowWordButtons()
        updateNextButton()
    }

    private func clearButtons() {
        pendingButtons.forEach { $0.removeFromSuperview() }
        submittedButtons.forEach { $0.removeFromSuperview() }

        pendingButtons = []
        submittedButtons = []
        orderedButtons = []
        wordValues = [:]
        positions = [:]
        originalPositions = [:]
    }

    private func setupNavigationItem() {
        let resetButton = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        resetButton.setImage(R.image.iconRetry(), for: .normal)
        resetButton.addTarget(self, action: #selector(actionRetry), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: resetButton)
    }

    private func createSkipButton() {
        let skipButton = TriangularedButton()
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.applyAccessoryStyle()
        buttonsView.addSubview(skipButton)

        skipButton.addTarget(
            self,
            action: #selector(actionSkip),
            for: .touchUpInside
        )

        self.skipButton = skipButton
        if let adaptiveLayout {
            adaptiveLayout.addSkip(skipButton, to: buttonsView, above: nextButton)
            return
        }

        skipButton.leadingAnchor.constraint(equalTo: buttonsView.leadingAnchor).isActive = true
        skipButton.trailingAnchor.constraint(equalTo: buttonsView.trailingAnchor).isActive = true
        skipButton.bottomAnchor.constraint(
            equalTo: nextButton.topAnchor,
            constant: -UIConstants.mainAccessoryActionsSpacing
        ).isActive = true
        skipButton.heightAnchor.constraint(equalToConstant: UIConstants.actionHeight).isActive = true

        buttonsHeightConstraint.constant = 2.0 * UIConstants.actionHeight + UIConstants.mainAccessoryActionsSpacing

        self.skipButton = skipButton
    }

    private func updateNextButton() {
        let isEnabled = pendingButtons.isEmpty && !submittedButtons.isEmpty
        nextButton.set(enabled: isEnabled)
    }

    @objc private func actionRetry() {
        presenter.requestWords()
    }

    @IBAction private func actionNext() {
        guard pendingButtons.isEmpty else {
            return
        }

        let words = submittedButtons.compactMap { wordValues[$0] }
        guard words.count == submittedButtons.count else { return }
        presenter.confirm(words: words)
    }

    @objc private func actionSkip() {
        presenter.skip()
    }
}

extension AccountConfirmViewController {
    private func setupLegacyHeading() {
        // A navigation-bar title cannot wrap at large text sizes. Keep the native navigation
        // controls and controller title, and expose the full heading in the scroll content.
        navigationItem.titleView = UIView()
        let heading = UILabel()
        heading.translatesAutoresizingMaskIntoConstraints = false
        heading.numberOfLines = 0
        heading.textColor = detailsLabel.textColor
        heading.accessibilityTraits.insert(.header)
        contentView.constraints.filter {
            $0.firstItem as? UIView === topPlaneView && $0.firstAttribute == .top
        }.forEach { $0.isActive = false }
        contentView.addSubview(heading)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            heading.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26),
            topPlaneView.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 16)
        ])
        legacyHeadingLabel = heading
    }

    private func refreshAdaptiveTypography() {
        adaptiveLayout?.refresh(
            title: title,
            details: detailsLabel,
            actions: [nextButton, skipButton].compactMap { $0 },
            locale: selectedLocale,
            traits: traitCollection
        )
        if adaptiveLayout == nil {
            legacyHeadingLabel?.text = title
            legacyHeadingLabel?.font = .legacySora(
                size: 18, weight: .bold, textStyle: .title3, compatibleWith: traitCollection
            )
            detailsLabel.font = .legacySora(
                size: 16, weight: .regular, textStyle: .body, compatibleWith: traitCollection
            )
            [nextButton, skipButton].compactMap { $0 }.forEach { button in
                let isPrimary = button === nextButton
                let minimumHeight: CGFloat = isPrimary
                    ? (showsExactMnemonicSpacing ? 56 : 52) : UIConstants.actionHeight
                button.configureWrappingTitle(
                    locale: selectedLocale, compatibleWith: traitCollection, minimumHeight: minimumHeight
                )
                button.wrappingLabel?.font = .legacySora(
                    size: isPrimary ? 16 : 14, weight: .bold,
                    textStyle: isPrimary ? .headline : .subheadline, compatibleWith: traitCollection
                )
                button.wrappingLabel?.lineBreakMode = .byCharWrapping
            }
        }
        orderedButtons.compactMap { $0 as? AccountConfirmWordButton }.forEach {
            $0.refresh(locale: selectedLocale, traits: traitCollection, adaptiveFont: adaptiveLayout != nil)
        }
        needsAdaptiveReflow = true
        view.setNeedsLayout()
    }

    private func displayTitle(for word: String) -> String {
        guard showsExactMnemonicSpacing else { return word }
        let languages = selectedLocale.rLanguages
        if word.isEmpty {
            return "[" + R.string.localizable.confirmationExactEmpty(preferredLanguages: languages) + "]"
        }
        return word.unicodeScalars.map { scalar in
            let name: String
            switch scalar.value {
            case 9: name = R.string.localizable.confirmationExactTab(preferredLanguages: languages)
            case 10: name = R.string.localizable.confirmationExactLineBreak(preferredLanguages: languages)
            case 13: name = R.string.localizable.confirmationExactCarriageReturn(preferredLanguages: languages)
            default:
                guard CharacterSet.whitespacesAndNewlines.contains(scalar) else { return String(scalar) }
                name = String(format: "U+%04X", scalar.value)
            }
            return " [" + name + "] "
        }.joined()
    }

    private func layoutButtons() {
        layoutPendingButtons()
        layoutSubmittedButtons()
    }

    private func layoutSubmittedButtons() {
        let rows = createRowsFromButtons(submittedButtons)
        let height = layoutRows(rows, on: topPlaneView)
        topPlaneHeight.constant = max(minHeight, height + 2.0 * Constants.internalMargin)
    }

    private func layoutPendingButtons() {
        let rows = createRowsFromButtons(pendingButtons)
        let height = layoutRows(rows, on: bottomPlaneView)
        bottomPlaneHeight.constant = max(minHeight, height + 2.0 * Constants.internalMargin)
    }

    private func createRowsFromButtons(_ buttons: [RoundedButton]) -> [[RoundedButton]] {
        let availableWidth = contentWidth - 2.0 * Constants.internalMargin

        var targetButtonIndex = 0

        var rows: [[RoundedButton]] = []

        var row: [RoundedButton] = []

        var remainedWidth = availableWidth

        while targetButtonIndex < buttons.count {
            let size = buttons[targetButtonIndex].intrinsicContentSize

            if size.width <= remainedWidth {
                row.append(buttons[targetButtonIndex])

                remainedWidth -= size.width + Constants.itemsSpacing

                targetButtonIndex += 1
            } else {
                if !row.isEmpty {
                    rows.append(row)
                    row = []
                } else {
                    break
                }

                remainedWidth = availableWidth
            }
        }

        if !row.isEmpty {
            rows.append(row)
        }

        return rows
    }

    private func layoutRows(_ rows: [[RoundedButton]], on plane: UIView) -> CGFloat {
        var currentY = Constants.internalMargin

        let availableWidth = contentWidth - 2.0 * Constants.internalMargin

        var totalHeight: CGFloat = 0.0

        for row in rows {
            var width = row.reduce(CGFloat(0.0)) { result, item in
                result + item.intrinsicContentSize.width
            }

            width += CGFloat(row.count - 1) * Constants.itemsSpacing

            let height = row.reduce(CGFloat(0.0)) { result, item in
                max(result, item.intrinsicContentSize.height)
            }

            var originX = Constants.internalMargin + availableWidth / 2.0 - width / 2.0

            for item in row {
                let size = item.intrinsicContentSize

                if let position = positions[item] {
                    position.leading.isActive = false
                    position.top.isActive = false
                }

                let leading = item.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: originX
                )

                let itemY = currentY + height / 2.0 - size.height / 2.0
                let top = item.topAnchor.constraint(
                    equalTo: plane.topAnchor,
                    constant: itemY
                )

                leading.isActive = true
                top.isActive = true

                positions[item] = Position(leading: leading, top: top)

                originX += size.width + Constants.itemsSpacing
            }

            currentY += height + Constants.itemsSpacing

            totalHeight += height
        }

        return totalHeight + CGFloat(rows.count - 1) * Constants.itemsSpacing
    }

    @objc private func actionItem(_ sender: AnyObject) {
        guard let button = sender as? RoundedButton else {
            return
        }

        if let index = pendingButtons.firstIndex(of: button) {
            pendingButtons.remove(at: index)
            submittedButtons.append(button)

            originalPositions[button] = positions[button]

            let animationBlock = {
                button.roundedBackgroundView?.fillColor = R.color.colorHighlightedPink()!
                button.roundedBackgroundView?.highlightedFillColor = R.color.colorHighlightedPink()!
                button.changesContentOpacityWhenHighlighted = true
                self.layoutSubmittedButtons()

                self.contentView.layoutIfNeeded()
            }

            wordTransitionAnimation.animate(
                block: animationBlock,
                completionBlock: nil
            )
        } else if let index = submittedButtons.firstIndex(of: button) {
            submittedButtons.remove(at: index)
            pendingButtons.append(button)

            let currentPosition = positions[button]
            positions[button] = originalPositions[button]

            let animationBlock = {
                button.roundedBackgroundView?.fillColor = R.color.colorPink()!
                button.roundedBackgroundView?.highlightedFillColor = R.color.colorHighlightedAccent()!
                button.changesContentOpacityWhenHighlighted = false

                currentPosition?.leading.isActive = false
                currentPosition?.top.isActive = false

                if let originalPosition = self.originalPositions[button] {
                    originalPosition.leading.isActive = true
                    originalPosition.top.isActive = true
                }

                self.layoutSubmittedButtons()

                self.contentView.layoutIfNeeded()
            }

            wordTransitionAnimation.animate(
                block: animationBlock,
                completionBlock: nil
            )
        }

        updateNextButton()
    }
}

extension AccountConfirmViewController: AccountConfirmViewProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        if afterConfirmationFail {
            wrongSequenceAnimation.animate(view: contentView) { _ in
                self.apply(words: words)
                self.retryAnimation.animate(
                    view: self.contentView,
                    completionBlock: nil
                )
            }

            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        } else {
            apply(words: words)

            retryAnimation.animate(
                view: contentView,
                completionBlock: nil
            )
        }
    }
}

extension AccountConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension AccountConfirmViewController {
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil, isViewLoaded {
            presenter.willLeaveView()
        }
        super.willMove(toParent: parent)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil, isViewLoaded {
            presenter.didLeaveView()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            presenter.willLeaveView()
            if let transitionCoordinator {
                transitionCoordinator.animate(alongsideTransition: nil) { [weak self] context in
                    if context.isCancelled {
                        self?.presenter.didCancelLeavingView()
                    } else {
                        self?.presenter.didLeaveView()
                    }
                }
            } else {
                presenter.didLeaveView()
            }
        }
    }
}
