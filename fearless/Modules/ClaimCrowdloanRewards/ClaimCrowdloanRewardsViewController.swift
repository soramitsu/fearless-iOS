import UIKit
import SoraFoundation

final class ClaimCrowdloanRewardsViewController: UIViewController, ViewHolder {
    typealias RootViewType = ClaimCrowdloanRewardsViewLayout

    // MARK: Private properties
    private let output: ClaimCrowdloanRewardsViewOutput

    // MARK: - Constructor
    init(
        output: ClaimCrowdloanRewardsViewOutput,
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
        view = ClaimCrowdloanRewardsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }
    
    // MARK: - Private methods
}

// MARK: - ClaimCrowdloanRewardsViewInput
extension ClaimCrowdloanRewardsViewController: ClaimCrowdloanRewardsViewInput {}

// MARK: - Localizable
extension ClaimCrowdloanRewardsViewController: Localizable {
    func applyLocalization() {}
}
