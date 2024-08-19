import UIKit
import SoraFoundation
import SSFModels

protocol MultichainAssetSelectionViewOutput: AnyObject {
    func didLoad(view: MultichainAssetSelectionViewInput)
    func didSelect(chain: ChainModel)
    func didTapCloseButton()
}

final class MultichainAssetSelectionViewController: UIViewController, ViewHolder {
    typealias RootViewType = MultichainAssetSelectionViewLayout

    // MARK: Private properties

    private let output: MultichainAssetSelectionViewOutput
    private let selectAssetViewController: UIViewController
    private var viewModels: [ChainSelectionCollectionCellModel]?

    // MARK: - Constructor

    init(
        output: MultichainAssetSelectionViewOutput,
        localizationManager: LocalizationManagerProtocol?,
        selectAssetViewController: UIViewController
    ) {
        self.output = output
        self.selectAssetViewController = selectAssetViewController

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = MultichainAssetSelectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        setupEmbededSelectAssetView()
        setupCollectionView()

        rootView.topBar.backButton.addAction { [weak self] in
            self?.output.didTapCloseButton()
        }
    }

    // MARK: - Private methods

    private func setupEmbededSelectAssetView() {
        addChild(selectAssetViewController)

        guard let view = selectAssetViewController.view else {
            return
        }

        rootView.addSelectAssetView(view)
        controller.didMove(toParent: self)
    }

    private func setupCollectionView() {
        rootView.chainsCollectionView.delegate = self
        rootView.chainsCollectionView.dataSource = self
        rootView.chainsCollectionView.registerClassForCell(ChainSelectionCollectionCell.self)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 40, height: 40)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        rootView.chainsCollectionView.collectionViewLayout = layout
    }
}

// MARK: - MultichainAssetSelectionViewInput

extension MultichainAssetSelectionViewController: MultichainAssetSelectionViewInput {
    func didReceive(viewModels: [ChainSelectionCollectionCellModel]) {
        self.viewModels = viewModels
        rootView.chainsCollectionView.reloadData()
    }
}

// MARK: - Localizable

extension MultichainAssetSelectionViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

extension MultichainAssetSelectionViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        (viewModels?.count).or(0)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCellWithType(ChainSelectionCollectionCell.self, forIndexPath: indexPath)
    }

    func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? ChainSelectionCollectionCell else {
            return
        }

        let viewModel = viewModels?[indexPath.item]
        cell.bind(viewModel: viewModel)
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let viewModel = viewModels?[indexPath.item]

        guard let chain = viewModel?.chain else {
            return
        }

        output.didSelect(chain: chain)
    }
}
