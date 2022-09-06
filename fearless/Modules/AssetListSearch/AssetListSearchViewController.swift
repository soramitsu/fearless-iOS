import UIKit
import SoraFoundation

final class AssetListSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetListSearchViewLayout

    // MARK: Private properties

    private let output: AssetListSearchViewOutput

    private let assetListViewController: UIViewController

    // MARK: - Constructor

    init(
        assetListViewController: UIViewController,
        output: AssetListSearchViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.assetListViewController = assetListViewController
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
        view = AssetListSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setup()
    }

    // MARK: - Private methods

    private func setup() {
        setupEmbededAssetList()

        rootView.cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        rootView.searchTextField.onTextDidChanged = { [weak self] text in
            self?.output.searchTextDidChange(text)
        }
    }

    private func setupEmbededAssetList() {
        addChild(assetListViewController)

        guard let view = assetListViewController.view else {
            return
        }

        rootView.addAssetList(view)
        controller.didMove(toParent: self)
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        output.didTapOnCalcel()
    }
}

// MARK: - AssetListSearchViewInput

extension AssetListSearchViewController: AssetListSearchViewInput {}

// MARK: - Localizable

extension AssetListSearchViewController: Localizable {
    func applyLocalization() {
        rootView.locale = selectedLocale
    }
}
