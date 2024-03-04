import UIKit
import SoraFoundation

protocol OnboardingViewOutput: AnyObject {
    func didLoad(view: OnboardingViewInput)
    func didTapSkipButton()
}

final class OnboardingViewController: UIViewController, ViewHolder {
    typealias RootViewType = OnboardingViewLayout

    // MARK: Private properties

    private let output: OnboardingViewOutput

    private var dataSource: CollectionViewDataSource<OnboardingPageCell, OnboardingPageViewModel>?

    // MARK: - Constructor

    init(
        output: OnboardingViewOutput,
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
        view = OnboardingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        rootView.collectionView.delegate = self
        setupActions()
    }

    // MARK: - Private methods

    private func setupActions() {
        rootView.nextButton.addAction { [weak self] in
            self?.showNextPage()
        }
        rootView.skipButton.addAction { [weak self] in
            self?.output.didTapSkipButton()
        }
    }
}

// MARK: - OnboardingViewInput

extension OnboardingViewController: OnboardingViewInput {
    @MainActor func didReceive(viewModel: OnboardingDataSource) async {
        dataSource = CollectionViewDataSource(data: viewModel.pages, cellClass: OnboardingPageCell.self) { model, cell in
            cell.bind(viewModel: model)
        }
        rootView.collectionView.dataSource = dataSource

        rootView.pageControl.numberOfPages = viewModel.pages.count
    }

    func showNextPage() {
        if let pagesCount = dataSource?.data.count, rootView.pageControl.currentPage + 1 < pagesCount {
            rootView.collectionView.scrollTo(
                horizontalPage: UIScrollView.Page(
                    intValue: rootView.pageControl.currentPage + 1,
                    direction: .horizontal(offset: 16)
                )
            )
        } else {
            output.didTapSkipButton()
        }
    }
}

// MARK: - Localizable

extension OnboardingViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}

// MARK: - UICollectionViewDelegate

extension OnboardingViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offSet = scrollView.contentOffset.x
        let width = scrollView.frame.width
        let horizontalCenter = width / 2

        rootView.pageControl.currentPage = Int(offSet + horizontalCenter) / Int(width)
    }
}
