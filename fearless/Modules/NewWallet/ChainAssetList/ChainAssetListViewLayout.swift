import UIKit
import SCard
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
    }

    enum ViewState {
        case normal
        case empty
    }

    var keyboardAdoptableConstraint: Constraint?

    weak var bannersView: UIView?
    private var soraCardCell: SCCardCell?

    var headerViewContainer: UIStackView = {
        UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    }()

    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)
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

    func addBanners(view: UIView) {
        bannersView = view
        bannersView?.isHidden = true
        headerViewContainer.addArrangedSubview(view)
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }

    func bindSoraCard(item: SCCardItem, isHidden: Bool) {
        let cell = SCCardCell()
        cell.set(item: item, context: nil)
        if soraCardCell == nil {
            soraCardCell = cell
            soraCardCell?.contentView.isHidden = isHidden
            headerViewContainer.addArrangedSubview(soraCardCell!.contentView)
            soraCardCell?.contentView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
    }

    func setSoraCard(isHidden: Bool) {
        soraCardCell?.contentView.isHidden = isHidden
    }

    private func setupLayout() {
        tableView.tableHeaderView = headerViewContainer
        headerViewContainer.snp.makeConstraints { make in
            make.width.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerX.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
