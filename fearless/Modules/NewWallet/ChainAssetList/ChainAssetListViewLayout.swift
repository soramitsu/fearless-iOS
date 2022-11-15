import UIKit
import SoraUI
import SnapKit

final class ChainAssetListViewLayout: UIView {
    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    private let container = UIView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: UIConstants.bigOffset, left: 0, bottom: UIConstants.bigOffset, right: 0)

        return view
    }()

    let emptyView: EmptyView = {
        let view = EmptyView()
        view.isHidden = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(emptyViewModel: EmptyViewModel) {
        emptyView.bind(viewModel: emptyViewModel)
    }

    func apply(state: ViewState) {
        switch state {
        case .normal:
            tableView.isHidden = false
            emptyView.isHidden = true
        case .empty:
            tableView.isHidden = true
            emptyView.isHidden = false
        }
    }

    private func setupLayout() {
        addSubview(container)
        container.addSubview(tableView)
        container.addSubview(emptyView)

        container.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }

        emptyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
