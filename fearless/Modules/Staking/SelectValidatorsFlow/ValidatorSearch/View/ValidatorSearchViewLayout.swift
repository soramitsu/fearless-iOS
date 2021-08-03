import UIKit
import SoraUI

final class ValidatorSearchViewLayout: UIView {
    private let searchContainer: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()!
        return view
    }()

    private let frameView: RoundedView = {
        let view = RoundedView()
        view.roundingCorners = .allCorners
        view.cornerRadius = 8
        view.fillColor = R.color.colorAlmostBlack()!
        return view
    }()

    private let searchImageView: UIImageView = {
        UIImageView(image: R.image.iconSearch())
    }()

    let searchField: UITextField = {
        let view = UITextField()
        view.tintColor = .white
        view.font = .p1Paragraph
        view.textColor = .white
        view.clearButtonMode = .whileEditing
        return view
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = R.color.colorBlack()
        tableView.separatorColor = R.color.colorDarkGray()
        return tableView
    }()

    let emptyStateContainer: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlack()
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

    private func setupLayout() {
        searchContainer.addSubview(frameView)
        searchContainer.addSubview(searchImageView)
        searchContainer.addSubview(searchField)

        frameView.snp.makeConstraints { make in
            make.height.equalTo(36)
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        searchImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
            make.centerY.equalToSuperview()
            make.leading.equalTo(frameView.snp.leading).inset(12)
        }

        searchField.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(frameView.snp.trailing).inset(8)
            make.leading.equalTo(searchImageView.snp.trailing).offset(10)
        }

        addSubview(searchContainer)
        searchContainer.snp.makeConstraints { make in
            make.height.equalTo(52)
            make.leading.top.trailing.equalTo(safeAreaLayoutGuide)
        }

        addSubview(emptyStateContainer)
        emptyStateContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(searchContainer.snp.bottom)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchContainer.snp.bottom)
            make.leading.bottom.trailing.equalTo(safeAreaLayoutGuide)
        }
    }
}
