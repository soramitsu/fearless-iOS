import UIKit
import SoraFoundation

final class NftCollectionViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    private enum Constants {
        static let bouncesThreshold: CGFloat = 1.0
        static let multiplierToActivateNextLoading: CGFloat = 1.5
    }

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
        rootView.collectionView.registerClassForCell(NftHeaderCell.self)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewAppeared()
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
    func collectionView(_: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowlayout = collectionViewLayout as? UICollectionViewFlowLayout
        switch indexPath.section {
        case 0:
            let space: CGFloat = (flowlayout?.sectionInset.left ?? 0.0) + (flowlayout?.sectionInset.right ?? 0.0)
            let width = rootView.collectionView.frame.size.width - space
            return CGSize(width: width, height: width)
        default:
            let space: CGFloat = (flowlayout?.minimumInteritemSpacing ?? 0.0) + (flowlayout?.sectionInset.left ?? 0.0) + (flowlayout?.sectionInset.right ?? 0.0)
            let size: CGFloat = (rootView.collectionView.frame.size.width - space) / 2.0
            return CGSize(width: size, height: 249)
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let sectionHeader = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "NftCollectionViewSectionHeader", for: indexPath) as! CollectionViewSectionHeader

            switch indexPath.section {
            case 0:
                return UICollectionReusableView()
            case 1:
                sectionHeader.label.text = R.string.localizable.nftCollectionMyNfts(preferredLanguages: selectedLocale.rLanguages)
            case 2:
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

    func collectionView(_ collectionView: UICollectionView, layout _: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch section {
        case 0:
            return .zero
        default:
            return CGSize(width: collectionView.frame.width, height: 44)
        }
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return viewModel?.ownedCellModels.count ?? 0
        case 2:
            return viewModel?.availableCellModels.count ?? 0
        default:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCellWithType(NftHeaderCell.self, forIndexPath: indexPath)
            let model = NftHeaderCellViewModel(
                imageViewModel: viewModel?.collectionImage,
                title: viewModel?.collectionDescription
            )
            cell.bind(cellModel: model)
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCellWithType(NftCell.self, forIndexPath: indexPath)
            cell.delegate = self
            if let cellModel = viewModel?.ownedCellModels[indexPath.item] {
                cell.bind(cellModel: cellModel)
            }
            return cell
        case 2:
            let cell = collectionView.dequeueReusableCellWithType(NftCell.self, forIndexPath: indexPath)
            cell.delegate = self
            if let cellModel = viewModel?.availableCellModels[indexPath.item] {
                cell.bind(cellModel: cellModel)
            }
            return cell
        default:
            return UICollectionViewCell(frame: .zero)
        }
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            return
        case 1:
            guard let viewModel = viewModel?.ownedCellModels[safe: indexPath.item] else {
                return
            }
            output.didSelect(nft: viewModel.nft, type: .owned)
        case 2:
            guard let viewModel = viewModel?.availableCellModels[safe: indexPath.item] else {
                return
            }
            output.didSelect(nft: viewModel.nft, type: .available)
        default:
            break
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        viewModel?.availableCellModels.isNotEmpty == true ? 3 : 2
    }
}

extension NftCollectionViewController: NftCellDelegate {
    func handle(cellModel: NftCellViewModel) {
        output.didTapActionButton(nft: cellModel.nft, type: cellModel.type)
    }
}

extension NftCollectionViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        handleDraggableOnScroll(scrollView: scrollView)
        handleNextPageOnScroll(scrollView: scrollView)
    }

    private func handleDraggableOnScroll(scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < Constants.bouncesThreshold {
            scrollView.bounces = false
            scrollView.showsVerticalScrollIndicator = false
        } else {
            scrollView.bounces = true
            scrollView.showsVerticalScrollIndicator = true
        }
    }

    private func handleNextPageOnScroll(scrollView: UIScrollView) {
        var threshold = scrollView.contentSize.height
        threshold -= scrollView.bounds.height * Constants.multiplierToActivateNextLoading

        if scrollView.contentOffset.y > threshold {
            output.loadNext()
        }
    }
}
