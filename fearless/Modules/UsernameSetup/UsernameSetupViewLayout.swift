import UIKit
import SoraUI
import SnapKit

final class UsernameSetupViewLayout: UIView {
    private enum Constants {
        static let strokeWidth: CGFloat = 1
        static let shadowOpacity: Float = 0
        static let contentBottomOffset: CGFloat = 92
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.alignment = .fill
        return view
    }()

    let chainView: BorderedSubtitleActionView = {
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
        view.actionControl.contentView.subtitleLabelView.numberOfLines = 1
        view.actionControl.imageIndicator.image = R.image.iconDropDown()
        view.disable()
        return view
    }()

    let chainViewContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    let usernameTextField: CommonInputView = {
        let inputView = CommonInputView()
        inputView.backgroundView.fillColor = R.color.colorBlack19()!
        inputView.backgroundView.shadowOpacity = 0
        inputView.backgroundView.strokeColor = R.color.colorGray()!
        inputView.backgroundView.highlightedStrokeColor = R.color.colorGray()!
        inputView.animatedInputField.placeholderColor = R.color.colorLightGray()!
        inputView.defaultSetup()
        return inputView
    }()

    let usernameTextFieldContainer = UIView()

    let hintLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 0
        return label
    }()

    let hintLabelContainer = UIView()

    let nextButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension UsernameSetupViewLayout {
    func handleKeyboard(frame: CGRect) {
        nextButton.snp.updateConstraints { make in
            make.bottom.equalTo(safeAreaLayoutGuide).inset(frame.height + UIConstants.bigOffset)
        }
    }
}

private extension UsernameSetupViewLayout {
    func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(Constants.contentBottomOffset)
        }

        chainViewContainer.addSubview(chainView)
        chainView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(chainViewContainer)

        usernameTextFieldContainer.addSubview(usernameTextField)
        usernameTextField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(usernameTextFieldContainer)

        hintLabelContainer.addSubview(hintLabel)
        hintLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview()
        }
        contentView.stackView.addArrangedSubview(hintLabelContainer)

        addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
        }
    }

    func applyLocalization() {
        nextButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        nextButton.invalidateLayout()
        hintLabel.text = R.string.localizable.usernameSetupHint(preferredLanguages: locale.rLanguages)
        usernameTextField.title = R.string.localizable.usernameSetupChooseTitle(preferredLanguages: locale.rLanguages)
        chainView.actionControl.contentView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
    }
}
