import UIKit
import SoraUI
import SoraFoundation
import SnapKit

final class AccountCreateViewLayout: UIView {
    private enum Constants {
        static let subviewToContainerOffset: CGFloat = 1
        static let strokeWidth: CGFloat = 1
        static let shadowOpacity: Float = 0
        static let dervationFieldToImageSpacing: CGFloat = 5
        static let derivationImageSize: Int = 24
        static let derivationPathLabelHeight: CGFloat = 15
        static let derivationPathViewToLabelSpacing: CGFloat = 12
        static let contentBottomOffset: CGFloat = 92
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
        button.applyEnabledStyle()
        return button
    }()

    let substrateDerivationPathImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let ethereumDerivationPathImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    let substrateCryptoTypeView: BorderedSubtitleActionView = {
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

    let ethereumCryptoTypeView: BorderedSubtitleActionView = {
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
        view.disable()
        return view
    }()

    let substrateDerivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = .white
        view.font = .p1Paragraph
        view.textColor = .white
        view.clearButtonMode = .whileEditing
        view.returnKeyType = .done
        return view
    }()

    let ethereumDerivationPathField: UITextField = {
        let view = UITextField()
        view.tintColor = .white
        view.font = .p1Paragraph
        view.textColor = .white
        view.clearButtonMode = .whileEditing
        view.keyboardType = .decimalPad
        view.returnKeyType = .done
        return view
    }()

    let substrateDerivationPathLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        return label
    }()

    let ethereumDerivationPathLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .left
        return label
    }()

    private let expandableControlContainerView: BorderedContainerView = {
        let view = UIFactory().createBorderedContainerView()
        view.backgroundColor = R.color.colorBlack()
        view.borderType = .bottom
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorGray()!
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

    private let substrateDerivationContainerView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = UIColor.clear
        view.highlightedFillColor = UIColor.clear
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    private let ethereumDerivationContainerView: TriangularedView = {
        let view = TriangularedView()
        view.shadowOpacity = Constants.shadowOpacity
        view.fillColor = UIColor.clear
        view.highlightedFillColor = UIColor.clear
        view.strokeColor = R.color.colorGray()!
        view.strokeWidth = Constants.strokeWidth
        return view
    }()

    private let advancedContainerView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = UIConstants.bigOffset
        return stackView
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

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configure()

        backgroundColor = .black
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AccountCreateViewLayout {
    func set(chainType: AccountCreateChainType) {
        substrateDerivationContainerView.isHidden = !chainType.includeSubstrate
        substrateDerivationPathField.isHidden = !chainType.includeSubstrate
        substrateDerivationPathImage.isHidden = !chainType.includeSubstrate
        substrateDerivationPathLabel.isHidden = !chainType.includeSubstrate
        substrateCryptoTypeView.isHidden = !chainType.includeSubstrate

        ethereumDerivationContainerView.isHidden = !chainType.includeEthereum
        ethereumDerivationPathField.isHidden = !chainType.includeEthereum
        ethereumDerivationPathImage.isHidden = !chainType.includeEthereum
        ethereumDerivationPathLabel.isHidden = !chainType.includeEthereum
        ethereumCryptoTypeView.isHidden = !chainType.includeEthereum
    }

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
        setupEthereumDerivationPathTextField()
    }

    private func setupEthereumDerivationPathTextField() {
        let bar = UIToolbar()
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(
            title: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            style: .done, target: self, action: #selector(close)
        )
        bar.items = [flexibleSpace, close]
        bar.sizeToFit()
        ethereumDerivationPathField.inputAccessoryView = bar
    }

    @objc private func close() {
        ethereumDerivationPathField.resignFirstResponder()
    }

    @objc
    private func actionExpand() {
        contentView.stackView.sendSubviewToBack(advancedContainerView)

        advancedContainerView.isHidden = !expandableControl.isActivated

        if expandableControl.isActivated {
            advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
        } else {
            substrateDerivationPathField.resignFirstResponder()
            ethereumDerivationPathField.resignFirstResponder()

            advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(Constants.contentBottomOffset)
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

        advancedContainerView.addArrangedSubview(substrateCryptoTypeView)
        substrateCryptoTypeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        substrateDerivationContainerView.addSubview(substrateDerivationPathField)
        substrateDerivationPathField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        substrateDerivationContainerView.addSubview(substrateDerivationPathImage)
        substrateDerivationPathImage.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(substrateDerivationPathField.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedContainerView.addArrangedSubview(substrateDerivationContainerView)
        substrateDerivationContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        advancedContainerView.addArrangedSubview(substrateDerivationPathLabel)
        substrateDerivationPathLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.derivationPathLabelHeight)
        }

        advancedContainerView.addArrangedSubview(ethereumCryptoTypeView)
        ethereumCryptoTypeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        ethereumDerivationContainerView.addSubview(ethereumDerivationPathField)
        ethereumDerivationPathField.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
        ethereumDerivationContainerView.addSubview(ethereumDerivationPathImage)
        ethereumDerivationPathImage.snp.makeConstraints { make in
            make.size.equalTo(Constants.derivationImageSize)
            make.leading.equalTo(ethereumDerivationPathField.snp.trailing).offset(Constants.dervationFieldToImageSpacing)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedContainerView.addArrangedSubview(ethereumDerivationContainerView)
        ethereumDerivationContainerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        advancedContainerView.addArrangedSubview(ethereumDerivationPathLabel)
        ethereumDerivationPathLabel.snp.makeConstraints { make in
            make.height.equalTo(Constants.derivationPathLabelHeight)
        }

        contentView.stackView.addArrangedSubview(advancedContainerView)

        addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
        }
    }

    private func applyLocalization() {
        detailsLabel.text = R.string.localizable.accountCreateDetails(preferredLanguages: locale.rLanguages)
        expandableControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)

        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
    }
}
