import UIKit
import SoraFoundation

final class NftCollectionViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = NftCollectionViewLayout
    private var viewModel: NftCollectionViewModel?

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
        rootView.collectionView.registerClassForCell(NftCell.self)
        rootView.collectionView.register(
            CollectionViewSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: "NftCollectionViewSectionHeader"
        )

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
        self.viewModel = viewModel

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
        return CGSize(width: size, height: 249)
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "NftCollectionViewSectionHeader", for: indexPath) as! CollectionViewSectionHeader

            switch indexPath.section {
            case 0:
                sectionHeader.label.text = R.string.localizable.nftCollectionMyNfts(preferredLanguages: selectedLocale.rLanguages)
            case 1:
                sectionHeader.label.text = R.string.localizable.nftCollectionAvailableNfts(
                    viewModel?.collectionName ?? "",
                    preferredLanguages: selectedLocale.rLanguages
                )
            default:
                break
            }
            return sectionHeader
        } else { // No footer in this case but can add option for that
            return UICollectionReusableView()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection _: Int) -> CGSize {
        CGSize(width: collectionView.frame.width, height: 44)
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return viewModel?.ownedCellModels.count ?? 0
        case 1:
            return viewModel?.availableCellModels.count ?? 0
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithType(NftCell.self, forIndexPath: indexPath)
        switch indexPath.section {
        case 0:
            if let cellModel = viewModel?.ownedCellModels[indexPath.item] {
                cell.bind(cellModel: cellModel)
            }
        case 1:
            if let cellModel = viewModel?.availableCellModels[indexPath.item] {
                cell.bind(cellModel: cellModel)
            }
        default:
            break
        }
        cell.delegate = self
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            guard let viewModel = viewModel?.ownedCellModels[safe: indexPath.item] else {
                return
            }
            output.didSelect(nft: viewModel.nft, type: .owned)
        case 1:
            guard let viewModel = viewModel?.availableCellModels[safe: indexPath.item] else {
                return
            }
            output.didSelect(nft: viewModel.nft, type: .available)
        default:
            break
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        viewModel?.availableCellModels.isNotEmpty == true ? 2 : 1
    }
}

extension NftCollectionViewController: NftCellDelegate {
    func handle(cellModel: NftCellViewModel) {
        output.didTapActionButton(nft: cellModel.nft, type: cellModel.type)
    }
}
