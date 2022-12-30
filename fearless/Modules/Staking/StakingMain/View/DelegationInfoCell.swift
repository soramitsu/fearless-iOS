import UIKit
import SoraFoundation

final class DelegationInfoCell: UITableViewCell {
    private lazy var stateView = DelegationStateView()

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
        stateView.locale = viewModel.locale ?? Locale.current
    }
}
