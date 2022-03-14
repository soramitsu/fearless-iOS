import UIKit
import SoraUI
import SoraFoundation

final class AccountCreateViewLayout: UIView {
    private enum Constants {
        static let subviewToContainerOffset: CGFloat = 1
        static let strokeWidth: CGFloat = 1
        static let shadowOpacity: Float = 0
        static let dervationFieldToImageSpacing: CGFloat = 5
        static let derivationImageSize: Int = 24
        static let derivationPathLabelHeight: CGFloat = 15
        static let derivationPathViewToLabelSpacing: CGFloat = 12
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    var mnemonicView: MnemonicDisplayView?

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.alignment = .fill
        return view
    }()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    let derivationPathImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let cryptoTypeView: BorderedSubtitleActionView = {
        let view = BorderedSubtitleActionView()
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeColor = R.color.colorGray()!
        view.highlightedStrokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        view.shadowOpacity = Constants.shadowOpacity
        view.actionControl.contentView.titleLabel.textColor = R.color.colorLightGray()
        view.actionControl.layoutType = BaseActionControl.LayoutType.flexible
        view.actionControl.contentView.titleLabel.font = .p2Paragraph
        view.actionControl.contentView.subtitleLabelView.textColor = R.color.colorWhite()
        view.actionControl.contentView.subtitleLabelView.font = .p1Paragraph
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        return view
    }()

    let derivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = .white
        view.font = .p1Paragraph
        view.textColor = .white
        view.clearButtonMode = .whileEditing
        return view
    }()

    let derivationPathLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        return label
    }()

    private let expandableControlContainerView: BorderedContainerView = {
        let view = UIFactory().createBorderedContainerView()
        view.backgroundColor = R.color.colorBlack()
        return view
    }()

    private let expandableControl: ExpandableActionControl = {
        let view = UIFactory().createExpandableActionControl()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private let detailsLabelView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()!
        return view
    }()

    private let derivationContainerView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = UIColor.clear
        view.highlightedFillColor = UIColor.clear
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    private let advancedContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()
        return view
    }()

    private let advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    private let advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AccountCreateViewLayout {
    func handleKeyboard(frame: CGRect) {
        nextButton.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(frame.height + UIConstants.bigOffset)
        }
    }
}

private extension AccountCreateViewLayout {
    private func configure() {
        contentView.stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.colorBlack() }
        advancedContainerView.isHidden = !expandableControl.isActivated
        expandableControl.addTarget(self, action: #selector(actionExpand), for: .touchUpInside)
    }

    @objc
    private func actionExpand() {
        contentView.stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expandableControl.isActivated

        if expandableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            derivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        detailsLabelView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
        contentView.stackView.addArrangedSubview(detailsLabelView)

        expandableControlContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.expandableViewHeight)
        }
        expandableControlContainerView.addSubview(expandableControl)
        expandableControl.snp.makeConstraints { make in
            make.edges.equalTo(expandableControlContainerView)
        }

        contentView.stackView.addArrangedSubview(expandableControlContainerView)

        advancedContainerView.addSubview(cryptoTypeView)
        cryptoTypeView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.subviewToContainerOffset)
            make.trailing.equalToSuperview().inset(Constants.subviewToContainerOffset)
            make.top.equalToSuperview().offset(UIConstants.bigOffset)
        }
        advancedContainerView.bringSubviewToFront(cryptoTypeView)

        derivationContainerView.addSubview(derivationPathField)
        derivationPathField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        derivationContainerView.addSubview(derivationPathImage)
        derivationPathImage.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(derivationPathField.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedContainerView.addSubview(derivationContainerView)
        derivationContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.subviewToContainerOffset)
            make.trailing.equalToSuperview().inset(Constants.subviewToContainerOffset)
            make.top.equalTo(cryptoTypeView.snp.bottom).offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        advancedContainerView.addSubview(derivationPathLabel)
        derivationPathLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.subviewToContainerOffset)
            make.trailing.equalToSuperview().inset(Constants.subviewToContainerOffset)
            make.height.equalTo(Constants.derivationPathLabelHeight)
            make.top.equalTo(derivationContainerView.snp.bottom).offset(Constants.derivationPathViewToLabelSpacing)
        }

        contentView.stackView.addArrangedSubview(advancedContainerView)

        addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.top.greaterThanOrEqualTo(UIConstants.hugeOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }

    private func applyLocalization() {
        detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }
}
