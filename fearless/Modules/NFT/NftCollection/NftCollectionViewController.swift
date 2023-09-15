import UIKit
import SoraFoundation

final class NftCollectionViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = NftCollectionViewLayout
    private var cellModels: [NftCollectionCellViewModel]?

    // MARK: Private properties

    private let output: NftCollectionViewOutput

    // MARK: - Constructor

    init(
        output: NftCollectionViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = NftCollectionViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self
        rootView.collectionView.registerClassForCell(NftCollectionCell.self)

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }
    }

    // MARK: - Private methods
}

// MARK: - NftCollectionViewInput

extension NftCollectionViewController: NftCollectionViewInput {
    func didReceive(viewModel: NftCollectionViewModel) {
        rootView.bind(viewModel: viewModel)
        cellModels = viewModel.cellModels

        rootView.collectionView.collectionViewLayout.invalidateLayout()
        rootView.collectionView.reloadData()
    }
}

// MARK: - Localizable

extension NftCollectionViewController: Localizable {
    func applyLocalization() {}
}

// MARK: - CollectionView

extension NftCollectionViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        let flowayout = collectionViewLayout as? UICollectionViewFlowLayout
        let space: CGFloat = (flowayout?.minimumInteritemSpacing ?? 0.0) + (flowayout?.sectionInset.left ?? 0.0) + (flowayout?.sectionInset.right ?? 0.0)
        let size: CGFloat = (rootView.collectionView.frame.size.width - space) / 2.0
        return CGSize(width: size, height: 233)
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        cellModels?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(NftCollectionCell.self, forIndexPath: indexPath)
        if let cellModel = cellModels?[indexPath.item] {
            cell.bind(cellModel: cellModel)
        }
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let viewModel = cellModels?[safe: indexPath.item] else {
            return
        }

        output.didSelect(nft: viewModel.nft)
    }
}
