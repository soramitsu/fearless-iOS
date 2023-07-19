import UIKit
import SoraFoundation

protocol BannersViewOutput: AnyObject {
    func didLoad(view: BannersViewInput)
    func didTapOnCell(at indexPath: IndexPath)
}

final class BannersViewController: UIViewController, ViewHolder {
    typealias RootViewType = BannersViewLayout

    // MARK: Private properties

    private let output: BannersViewOutput

    private var dataSource: CollectionViewDataSource<BannerCollectionViewCell, BannerCellViewModel>?

    // MARK: - Constructor

    init(
        output: BannersViewOutput,
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
        view = BannersViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        rootView.collectionView.delegate = self
    }

    // MARK: - Private methods
}

// MARK: - BannersViewInput

extension BannersViewController: BannersViewInput {
    var isVisible: Bool {
        dataSource?.data.isNotEmpty ?? true
    }

    func didReceive(viewModel: BannersViewModel) {
        dataSource = CollectionViewDataSource(data: viewModel.banners, cellClass: BannerCollectionViewCell.self) { model, cell in
            cell.bind(viewModel: model)
            cell.delegate = self
        }
        rootView.collectionView.dataSource = dataSource

        rootView.setPageControl(pageCount: viewModel.banners.count)
    }
}

// MARK: - Localizable

extension BannersViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - BannerCellectionCellDelegate

extension BannersViewController: BannerCellectionCellDelegate {
    func didActionButtonTapped(indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            return
        }
        output.didTapOnCell(at: indexPath)
    }
}

// MARK: - UICollectionViewDelegate

extension BannersViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offSet = scrollView.contentOffset.x
        let width = scrollView.frame.width
        let horizontalCenter = width / 2

        rootView.pageControl.currentPage = Int(offSet + horizontalCenter) / Int(width)
    }
}
