import SoraSwiftUI
import SoraUI

final class PreparationViewLayout: UIView {
    private let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = UIConstants.hugeOffset
        return view
    }()

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        bar.backgroundColor = R.color.colorBlack()
        return bar
    }()

    private let warningLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphBoldM
        label.sora.textColor = .fgPrimary
        label.sora.contentInsets = .init(all: UIConstants.bigOffset)
        label.sora.backgroundColor = .bgSurface
        label.sora.cornerRadius = .small
        label.sora.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let step1View = SummaryStepView(step: "1")
    private let step2View = SummaryStepView(step: "2")
    private let step3View = SummaryStepView(step: "3")
    private let step4View = SummaryStepView(step: "4")
    private let step5View = SummaryStepView(step: "5")

    let confirmButton: RoundedButton = {
        let button = RoundedButton()
        button.applySoraSecondaryStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.bgPage()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension PreparationViewLayout {
    private func createSteps() -> [UIView] {
        [
            SummaryStepView(
                step: "1",
                title: R.string.localizable
                    .soraCardPreparationStep1Title(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable
                    .soraCardPreparationStep1Description(preferredLanguages: locale.rLanguages)
            ),
            SummaryStepView(
                step: "2",
                title: R.string.localizable
                    .soraCardPreparationStep2Title(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable
                    .soraCardPreparationStep2Description(preferredLanguages: locale.rLanguages)
            ),
            SummaryStepView(
                step: "3",
                title: R.string.localizable
                    .soraCardPreparationStep3Title(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable
                    .soraCardPreparationStep3Description(preferredLanguages: locale.rLanguages)
            ),
            SummaryStepView(
                step: "4",
                title: R.string.localizable
                    .soraCardPreparationStep4Title(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable
                    .soraCardPreparationStep4Description(preferredLanguages: locale.rLanguages)
            ),
            SummaryStepView(
                step: "5",
                title: R.string.localizable
                    .soraCardPreparationStep5Title(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable
                    .soraCardPreparationStep5Description(preferredLanguages: locale.rLanguages)
            )
        ]
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubviews([
            warningLabel,
            step1View,
            step2View,
            step3View,
            step4View,
            step5View,
            confirmButton
        ])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.leading.bottom.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.bigOffset)
        }

        contentView.stackView.subviews.forEach { view in
            view.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }
        }

        confirmButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.soraCardButtonHeight)
        }
    }

    private func applyLocalization() {
        let warningLabelTitle = SoramitsuTextItem(
            text: R.string.localizable.soraCardPreparationWarningTitle(preferredLanguages: locale.rLanguages).uppercased(),
            fontData: FontType.textBoldM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelTextStart = SoramitsuTextItem(
            text: R.string.localizable
                .soraCardPreparationWarningTextStart(preferredLanguages: locale.rLanguages),
            fontData: FontType.textM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelAccent = SoramitsuTextItem(
            text: R.string.localizable
                .soraCardPreparationWarningAccent(preferredLanguages: locale.rLanguages),
            fontData: FontType.textBoldM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelTextEnd = SoramitsuTextItem(
            text: R.string.localizable
                .soraCardPreparationWarningTextEnd(preferredLanguages: locale.rLanguages),
            fontData: FontType.textM,
            textColor: .fgPrimary,
            alignment: .left
        )
        let warningLabelText = NSMutableAttributedString()
        warningLabelText.append(warningLabelTitle.attributedString)
        warningLabelText.append(warningLabelTextStart.attributedString)
        warningLabelText.append(warningLabelAccent.attributedString)
        warningLabelText.append(warningLabelTextEnd.attributedString)
        warningLabel.sora.attributedText = warningLabelText

        navigationBar.setTitle(
            R.string.localizable.verifyPhoneNumberTitle(preferredLanguages: locale.rLanguages)
        )
        step1View.titleLable.sora.text = R.string.localizable
            .soraCardPreparationStep1Title(preferredLanguages: locale.rLanguages)
        step1View.subtitleLable.sora.text = R.string.localizable
            .soraCardPreparationStep1Description(preferredLanguages: locale.rLanguages)
        step2View.titleLable.sora.text = R.string.localizable
            .soraCardPreparationStep2Title(preferredLanguages: locale.rLanguages)
        step2View.subtitleLable.sora.text = R.string.localizable
            .soraCardPreparationStep2Description(preferredLanguages: locale.rLanguages)
        step3View.titleLable.sora.text = R.string.localizable
            .soraCardPreparationStep3Title(preferredLanguages: locale.rLanguages)
        step3View.subtitleLable.sora.text = R.string.localizable
            .soraCardPreparationStep3Description(preferredLanguages: locale.rLanguages)
        step4View.titleLable.sora.text = R.string.localizable
            .soraCardPreparationStep4Title(preferredLanguages: locale.rLanguages)
        step4View.subtitleLable.sora.text = R.string.localizable
            .soraCardPreparationStep4Description(preferredLanguages: locale.rLanguages)
        step5View.titleLable.sora.text = R.string.localizable
            .soraCardPreparationStep5Title(preferredLanguages: locale.rLanguages)
        step5View.subtitleLable.sora.text = R.string.localizable
            .soraCardPreparationStep5Description(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable
            .soraCardPreparationConfirmButtonTitle(preferredLanguages: locale.rLanguages).uppercased()
    }
}
