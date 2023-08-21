import UIKit
import SoraUI

final class ProfileViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = R.color.colorBlack()
        view.separatorStyle = .none
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack()
        setupLayout()
        configureTableView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func configureTableView() {
        tableView.register(
            UINib(resource: R.nib.profileTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.profileDetailsTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileDetailsCellId.identifier
        )

        tableView.register(
            UINib(resource: R.nib.profileSectionTableViewCell),
            forCellReuseIdentifier: R.reuseIdentifier.profileSectionCellId.identifier
        )
        tableView.registerClassForCell(WalletsManagmentTableCell.self)

        tableView.alwaysBounceVertical = false
    }
}
