import UIKit
import SoraUI

final class ChainAssetListViewLayout: UIView {
    enum ViewState {
        case normal
        case empty
    }

    let runtimesCountLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textAlignment = .center
        return label
    }()

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

    func bindRuntimeLabel(count: Int) {
        let text = "\(count) / 200"
        runtimesCountLabel.text = text
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
        addSubview(emptyView)
        addSubview(tableView)
        addSubview(runtimesCountLabel)

        emptyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        runtimesCountLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(30)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(runtimesCountLabel.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
