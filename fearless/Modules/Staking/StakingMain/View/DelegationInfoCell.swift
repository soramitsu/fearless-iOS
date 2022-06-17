import UIKit
import SoraFoundation

protocol DelegationInfoCellDelegate: AnyObject {
    func manageButtonClicked()
}

final class DelegationInfoCell: UITableViewCell {
    private lazy var stateView: NominatorStateView = {
        let view = NominatorStateView()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = .clear

        selectionStyle = .none
    }

    func setupLayout() {
        contentView.addSubview(stateView)
        stateView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.trailing.leading.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
    }

    func bind(to viewModel: DelegationInfoCellModel) {
        stateView.bind(viewModel: viewModel.contentViewModel)
        stateView.delegate = viewModel
    }

//    private weak var delegate: DelegationInfoCellModelDelegate?
//
//    private enum LayoutConstants {
//        static let buttonSize: CGFloat = 24
//    }
//
//    let nameLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p1Paragraph
//        label.textColor = .white
//        return label
//    }()
//
//    let manageButton: UIButton = {
//        let button = UIButton()
//        button.setImage(R.image.iconHorMore(), for: .normal)
//        return button
//    }()
//
//    let stakedStack: UIStackView = {
//        let stackView = UIStackView()
//        stackView.axis = .vertical
//        stackView.spacing = UIConstants.minimalOffset
//        return stackView
//    }()
//
//    let stakedTitleLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p2Paragraph
//        label.textColor = R.color.colorTransparentText()
//        return label
//    }()
//
//    let stakedAmountLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p0Paragraph
//        label.textColor = .white
//        return label
//    }()
//
//    let stakedSumLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p2Paragraph
//        label.textColor = R.color.colorTransparentText()
//        return label
//    }()
//
//    let rewardStack: UIStackView = {
//        let stackView = UIStackView()
//        stackView.axis = .vertical
//        stackView.spacing = UIConstants.minimalOffset
//        return stackView
//    }()
//
//    let rewardTitleLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p2Paragraph
//        label.textColor = R.color.colorTransparentText()
//        return label
//    }()
//
//    let rewardAmountLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p0Paragraph
//        label.textColor = .white
//        return label
//    }()
//
//    let rewardSumLabel: UILabel = {
//        let label = UILabel()
//        label.font = .p2Paragraph
//        label.textColor = R.color.colorTransparentText()
//        return label
//    }()
//
//    let delegationInfoContainerStack: UIStackView = {
//        let stackView = UIStackView()
//        stackView.axis = .horizontal
//        return stackView
//    }()
//
//    let separatorView: UIView = {
//        let view = UIView()
//        view.backgroundColor = R.color.colorBlurSeparator()
//        return view
//    }()
//
//    let statusView = StatusView()
//
//    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
//        super.init(style: style, reuseIdentifier: reuseIdentifier)
//
//        configure()
//        setupLayout()
//    }
//
//    @available(*, unavailable)
//    required init?(coder _: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    private func configure() {
//        backgroundColor = .clear
//
//        selectionStyle = .none
//
//        manageButton.addTarget(
//            self,
//            action: #selector(manageButtonClicked),
//            for: .touchUpInside
//        )
//    }
//
//    @objc private func manageButtonClicked() {
//        delegate?.manageDelegation()
//    }
//
//    private func setupLayout() {
//        contentView.addSubview(nameLabel)
//        contentView.addSubview(manageButton)
//
//        stakedStack.addArrangedSubview(stakedTitleLabel)
//        stakedStack.addArrangedSubview(stakedAmountLabel)
//        stakedStack.addArrangedSubview(stakedSumLabel)
//        delegationInfoContainerStack.addArrangedSubview(stakedStack)
//
//        rewardStack.addArrangedSubview(rewardTitleLabel)
//        rewardStack.addArrangedSubview(rewardAmountLabel)
//        rewardStack.addArrangedSubview(rewardSumLabel)
//        delegationInfoContainerStack.addArrangedSubview(rewardStack)
//
//        contentView.addSubview(delegationInfoContainerStack)
//        contentView.addSubview(separatorView)
//        contentView.addSubview(statusView)
//
//        nameLabel.snp.makeConstraints { make in
//            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
//            make.top.equalToSuperview().offset(UIConstants.bigOffset)
//        }
//
//        manageButton.snp.makeConstraints { make in
//            make.top.equalToSuperview().offset(UIConstants.bigOffset)
//            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
//            make.size.equalTo(LayoutConstants.buttonSize)
//        }
//
//        delegationInfoContainerStack.snp.makeConstraints { make in
//            make.top.equalTo(nameLabel.snp.bottom).offset(UIConstants.bigOffset)
//            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
//            make.trailing.equalToSuperview().offset(UIConstants.bigOffset)
//        }
//
//        separatorView.snp.makeConstraints { make in
//            make.top.equalTo(delegationInfoContainerStack.snp.bottom).offset(UIConstants.hugeOffset)
//            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
//            make.trailing.equalToSuperview().offset(UIConstants.bigOffset)
//        }
//
//        statusView.snp.makeConstraints { make in
//            make.top.equalTo(separatorView.snp.bottom).offset(UIConstants.bigOffset)
//            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
//            make.trailing.equalToSuperview().offset(UIConstants.bigOffset)
//        }
//    }
//
//    func bind(to _: DelegationInfoCellModel) {
//
//    }
}
