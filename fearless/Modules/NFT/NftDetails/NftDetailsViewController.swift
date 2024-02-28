import UIKit
import SoraFoundation

final class NftDetailsViewController: UIViewController, ViewHolder, HiddableBarWhenPushed {
    typealias RootViewType = NftDetailsViewLayout

    // MARK: Private properties

    private let output: NftDetailsViewOutput

    // MARK: - Constructor

    init(
        output: NftDetailsViewOutput,
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
        view = NftDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)

        rootView.navigationBar.backButton.addAction { [weak self] in
            self?.output.didBackButtonTapped()
        }

        rootView.sendButton.addAction { [weak self] in
            self?.output.didTapSendButton()
        }

        rootView.shareButton.addAction { [weak self] in
            self?.output.didTapShareButton()
        }

        rootView.ownerView.onCopy = { [weak self] in
            self?.output.didTapCopy()
        }

        rootView.tokenIdView.onCopy = { [weak self] in
            self?.output.didTapCopy()
        }

        rootView.creatorView.onCopy = { [weak self] in
            self?.output.didTapCopy()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        output.viewAppeared()
    }

    // MARK: - Private methods
}

// MARK: - NftDetailsViewInput

extension NftDetailsViewController: NftDetailsViewInput {
    func didReceive(viewModel: NftDetailViewModel) {
        rootView.bind(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension NftDetailsViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
