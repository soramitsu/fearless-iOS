import UIKit
import SoraUI
import SnapKit

final class ChainAssetListViewLayout: UIView {
    private enum Constants {
        static let tableViewContentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )

        static let cardContainerHeight: CGFloat = 80
    }

    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    private let cardContainer = UIView()
    private let contentContainer = UIView()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)
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
        addSubview(cardContainer)
        addSubview(contentContainer)
        contentContainer.addSubview(tableView)
        contentContainer.addSubview(emptyView)

        cardContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(Constants.cardContainerHeight)
        }

        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(cardContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().constraint
        }

        emptyView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func addChild(soraCardView: UIView) {
        cardContainer.addSubview(soraCardView)
        soraCardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
