import Foundation
import UIKit
import SoraUI

final class ScamWarningExpandableView: TriangularedView {
    private enum Constants {
        static let warningIconSize = CGSize(width: 20, height: 18)
        static let expandableIconSize = CGSize(width: 12, height: 6)
        static let defaultViewHeight: CGFloat = 110.0
    }

    // MARK: - Private properties

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
        return label
    }()

    private let mainCloudView = UIView()
    private let expandableCloudView = UIView()

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

    private var isOpen = false

    // MARK: - Constructor

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupView()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(scamInfo: ScamInfo) {
        nameLabel.text = scamInfo.name
        reasonLabel.text = scamInfo.type.rawValue.capitalized
        additionalLabel.text = scamInfo.subtype

        switch scamInfo.type {
        case .unknown:
            break
        case .scam:
            set(highlighted: true, animated: true)
            warningImageView.tintColor = R.color.colorRed()
            titleLabel.textColor = R.color.colorRed()
        case .donation, .exchange, .sanctions:
            set(highlighted: false, animated: true)
            warningImageView.tintColor = R.color.colorOrange()
            titleLabel.textColor = R.color.colorOrange()
        }
    }

    func expand() {
        let offset = isOpen ? -85 : 85
        expandableCloudView.snp.updateConstraints { make in
            make.top.equalTo(mainCloudView.snp.bottom).offset(offset)
        }
    }

    // MARK: - Private methods

    private func setupView() {
        clipsToBounds = true
        shadowOpacity = 0

        fillColor = R.color.colorSemiBlack()!
        highlightedFillColor = R.color.colorSemiBlack()!

        strokeColor = R.color.colorOrange()!
        highlightedStrokeColor = R.color.colorRed()!
    }

    private func setupLayout() {
        mainCloudView.backgroundColor = R.color.colorSemiBlack()!

        addSubview(mainCloudView)
        mainCloudView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        let vStackView = UIFactory.default.createVerticalStackView(spacing: 14)
        mainCloudView.addSubview(vStackView)
        vStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        warningImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.warningIconSize)
        }

        indicator.snp.makeConstraints { make in
            make.size.equalTo(Constants.expandableIconSize)
        }

        vStackView.addArrangedSubview(warningImageView)
        vStackView.addArrangedSubview(titleLabel)
        vStackView.addArrangedSubview(indicator)

        mainCloudView.addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(vStackView.snp.bottom).offset(UIConstants.verticalInset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview()
        }

        insertSubview(expandableCloudView, aboveSubview: mainCloudView)
        expandableCloudView.snp.makeConstraints { make in
            make.top.equalTo(mainCloudView.snp.bottom).offset(-85)
            make.leading.trailing.bottom.equalToSuperview()
        }

        let expandableStack = UIFactory.default.createHorizontalStackView(spacing: 8)

        let nameLabelStub = createLabel(with: "Name:")
        let nameView = createVStackViewFor(firstLabel: nameLabelStub, secondLabel: nameLabel)
        expandableStack.addArrangedSubview(nameView)

        let reasonLabelStub = createLabel(with: "Reason:")
        let reasonView = createVStackViewFor(firstLabel: reasonLabelStub, secondLabel: reasonLabel)
        expandableStack.addArrangedSubview(reasonView)

        let additionalLabelStub = createLabel(with: "Additional::")
        let additionalView = createVStackViewFor(firstLabel: additionalLabelStub, secondLabel: additionalLabel)
        expandableStack.addArrangedSubview(additionalView)
    }

    private func createVStackViewFor(firstLabel: UILabel, secondLabel: UILabel) -> UIView {
        let vStack = UIFactory.default.createVerticalStackView(spacing: 4)
        vStack.addArrangedSubview(firstLabel)
        vStack.addArrangedSubview(secondLabel)
        return vStack
    }

    private func createLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .h6Title
        label.textColor = R.color.colorGray()!
        return label
    }
}
