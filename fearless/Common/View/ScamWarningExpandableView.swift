import Foundation
import UIKit
import SoraUI

final class ScamWarningExpandableView: UIView {
    private enum Constants {
        static let warningIconSize = CGSize(width: 20, height: 18)
        static let expandableIconSize = CGSize(width: 12, height: 6)
        static let expandViewHeight: CGFloat = 68.0
    }

    // MARK: - Private properties

    private let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.isUserInteractionEnabled = true

        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!

        view.strokeColor = R.color.colorOrange()!
        view.highlightedStrokeColor = R.color.colorRed()!
        view.strokeWidth = 1.0

        return view
    }()

    private let warningImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarning()?.withRenderingMode(.alwaysTemplate)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    private let indicator: ImageActionIndicator = {
        let indicator = ImageActionIndicator()
        indicator.image = R.image.iconExpandable()
        return indicator
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    private let mainCloudView = UIView()
    private let expandableCloudView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    private let additionalLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Constructor

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(scamInfo: ScamInfo, assetName: String) {
        nameLabel.text = scamInfo.name
        reasonLabel.text = scamInfo.type.rawValue.capitalized
        additionalLabel.text = scamInfo.subtype

        applyStyle(for: scamInfo.type, assetName: assetName)
    }

    // MARK: - Private methods

    private func applyStyle(for type: ScamInfo.ScamType, assetName: String) {
        applyHighlight(type)

        descriptionLabel.text = type.description(for: locale, assetName: assetName)
    }

    private func applyHighlight(_ type: ScamInfo.ScamType) {
        backgroundView.set(highlighted: type.isScam, animated: false)

        let tintColor = type.isScam ? R.color.colorRed()! : R.color.colorOrange()!
        warningImageView.tintColor = tintColor
        titleLabel.tintColor = tintColor
    }

    private func configure() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture))
        addGestureRecognizer(tapGesture)
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.commonWarning(preferredLanguages: locale.rLanguages)
    }

    // swiftlint:disable function_body_length
    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        mainCloudView.backgroundColor = R.color.colorSemiBlack()!

        backgroundView.addSubview(mainCloudView)
        mainCloudView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.verticalInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: 14)
        hStackView.distribution = .fillProportionally
        hStackView.alignment = .center
        mainCloudView.addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        warningImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.warningIconSize)
        }

        indicator.snp.makeConstraints { make in
            make.size.equalTo(Constants.expandableIconSize)
        }

        hStackView.addArrangedSubview(warningImageView)
        hStackView.addArrangedSubview(titleLabel)
        hStackView.addArrangedSubview(indicator)

        mainCloudView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(hStackView.snp.bottom).offset(UIConstants.verticalInset)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.verticalInset)
        }

        backgroundView.insertSubview(expandableCloudView, belowSubview: mainCloudView)
        expandableCloudView.snp.makeConstraints { make in
            make.top.equalTo(mainCloudView.snp.bottom).offset(-Constants.expandViewHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().offset(-UIConstants.verticalInset)
        }

        let expandableStack = UIFactory.default.createVerticalStackView(spacing: 8)
        expandableCloudView.addSubview(expandableStack)
        expandableStack.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        let nameLabelStub = createLabel(with: R.string.localizable.scamNameStub(preferredLanguages: locale.rLanguages))
        let nameView = createVStackViewFor(firstLabel: nameLabelStub, secondLabel: nameLabel)
        expandableStack.addArrangedSubview(nameView)

        let reasonLabelStub = createLabel(with: R.string.localizable.scamReasonStub(
            preferredLanguages: locale.rLanguages)
        )
        let reasonView = createVStackViewFor(firstLabel: reasonLabelStub, secondLabel: reasonLabel)
        expandableStack.addArrangedSubview(reasonView)

        let additionalLabelStub = createLabel(with: R.string.localizable.scamAdditionalStub(
            preferredLanguages: locale.rLanguages)
        )
        let additionalView = createVStackViewFor(firstLabel: additionalLabelStub, secondLabel: additionalLabel)
        expandableStack.addArrangedSubview(additionalView)
    }

    private func createVStackViewFor(firstLabel: UILabel, secondLabel: UILabel) -> UIView {
        let hStack = UIFactory.default.createHorizontalStackView(spacing: 4)
        hStack.alignment = .leading
        hStack.addArrangedSubview(firstLabel)
        hStack.addArrangedSubview(secondLabel)
        return hStack
    }

    private func createLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.text = text
        label.font = .h6Title
        label.textColor = R.color.colorGray()!
        return label
    }

    // MARK: - Actions

    @objc private func handleTapGesture() {
        let isOpen = indicator.isActivated
        let offset = isOpen ? -Constants.expandViewHeight : 0
        expandableCloudView.isHidden = isOpen
        expandableCloudView.snp.updateConstraints { make in
            make.top.equalTo(mainCloudView.snp.bottom).offset(offset)
        }

        _ = isOpen ? indicator.deactivate() : indicator.activate()
    }
}
