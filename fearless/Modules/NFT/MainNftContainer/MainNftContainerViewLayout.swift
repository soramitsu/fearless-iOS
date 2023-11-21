import UIKit

enum NftCollectionAppearance {
    case collection
    case table
}

final class MainNftContainerViewLayout: UIView {
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.refreshControl = UIRefreshControl()
        tableView.separatorStyle = .none
        tableView.isHidden = true
        return tableView
    }()

    let collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: NftCollectionViewFlowLayout()
    )

    let nftContentControl = NFTContentControl()

    let emptyViewContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        tableView.backgroundColor = .clear
        collectionView.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        addSubview(collectionView)
        addSubview(nftContentControl)
        addSubview(emptyViewContainer)
        setupConstraints()
    }

    func bind(appearance: NftCollectionAppearance) {
        switch appearance {
        case .collection:
            nftContentControl.apply(state: .collection)

            collectionView.isHidden = false
            tableView.isHidden = true
        case .table:
            nftContentControl.apply(state: .table)

            collectionView.isHidden = true
            tableView.isHidden = false
        }
    }

    private func setupConstraints() {
        nftContentControl.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(nftContentControl.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(nftContentControl.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
        emptyViewContainer.snp.makeConstraints { make in
            make.top.equalTo(nftContentControl.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
