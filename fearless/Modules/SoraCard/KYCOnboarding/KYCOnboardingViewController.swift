import UIKit
import SoraFoundation
import PayWingsOnboardingKYC

final class KYCOnboardingViewController: UIViewController, ViewHolder {
    typealias RootViewType = KYCOnboardingViewLayout

    // MARK: Private properties

    private let output: KYCOnboardingViewOutput

    // MARK: - Constructor

    init(
        output: KYCOnboardingViewOutput,
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
        view = KYCOnboardingViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
    }

    // MARK: - Private methods
}

// MARK: - KYCOnboardingViewInput

extension KYCOnboardingViewController: KYCOnboardingViewInput {
    func didReceiveStartKycTrigger(with config: KycConfig, result: PayWingsOnboardingKYC.VerificationResult) {
        PayWingsOnboardingKyc.startKyc(vc: self, config: config, result: result)
    }
}

// MARK: - Localizable

extension KYCOnboardingViewController: Localizable {
    func applyLocalization() {}
}
