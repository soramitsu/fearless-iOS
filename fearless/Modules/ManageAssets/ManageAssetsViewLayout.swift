import UIKit

final class ManageAssetsViewLayout: UIView {
    let chainSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.strokeColor = R.color.colorStrokeGray()!
        view.highlightedStrokeColor = R.color.colorStrokeGray()!
        view.borderWidth = 1.0
        view.actionView.image = R.image.iconDropDown()
        view.layout = .singleTitle
        return view
    }()

    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.returnKeyType = .done
        searchBar.enablesReturnKeyAutomatically = false
        return searchBar
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorColor = R.color.colorDarkGray()
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: (UIConstants.bigOffset * 2) + UIConstants.actionHeight,
            right: 0
        )

        return view
    }()

    let applyButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    private func applyLocalization() {
        applyButton.imageWithTitleView?.title = R.string.localizable.commonApply(preferredLanguages: locale.rLanguages)
        searchBar.placeholder = R.string.localizable.manageAssetsSearchHint(preferredLanguages: locale.rLanguages)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        setupLayout()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: ManageAssetsViewModel) {
        applyButton.set(enabled: viewModel.applyEnabled, changeStyle: true)
        chainSelectionView.title = viewModel.selectedChain.title
        if viewModel.selectedChain.icon != nil {
            viewModel.selectedChain.icon?.loadImage(
                on: chainSelectionView.iconView,
                targetSize: CGSize(width: 21, height: 21),
                animated: true
            )
        } else {
            chainSelectionView.iconView.image = R.image.allNetworksIcon()
        }
    }

    private func setupLayout() {
        addSubview(chainSelectionView)
        addSubview(searchBar)
        addSubview(tableView)
        addSubview(applyButton)

        chainSelectionView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(48.0)
        }

        searchBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalTo(chainSelectionView.snp.bottom).offset(UIConstants.accessoryItemsSpacing)
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(searchBar.snp.bottom).offset(UIConstants.bigOffset)
        }

        applyButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
