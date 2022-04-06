import UIKit
import SoraFoundation

final class EducationStoriesViewController: UIViewController, ViewHolder {
    typealias RootViewType = BaseEducationStoriesView

    // MARK: Private properties

    private let presenter: EducationStoriesPresenterProtocol

    // MARK: - State

    private var state = EducationStoriesViewState.loading {
        didSet {
            applyState()
        }
    }

    // MARK: - Constructor

    init(
        presenter: EducationStoriesPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        presenter.didLoad(view: self)
    }

    override func loadView() {
        view = BaseEducationStoriesView()
    }

    // MARK: - Private methods

    private func applyState() {
        switch state {
        case .loading:
            break
        case let .loaded(slides):

            rootView.startShow(
                stories: slides,
                locale: selectedLocale
            ) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.presenter.didCloseStories()
            }
        }
    }
}

// MARK: - NewsVersion2ViewProtocol

extension EducationStoriesViewController: EducationStoriesViewProtocol {
    func didReceive(state: EducationStoriesViewState) {
        self.state = state
    }
}

// MARK: - Localizable

extension EducationStoriesViewController: Localizable {
    func applyLocalization() {}
}
