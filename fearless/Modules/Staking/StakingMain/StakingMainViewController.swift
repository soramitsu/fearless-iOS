import UIKit
import FearlessUtils
import SoraFoundation
import SoraUI

final class StakingMainViewController: UIViewController {
    var presenter: StakingMainPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!
    @IBOutlet private var actionButton: TriangularedButton!

    var iconGenerator: IconGenerating?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    @IBAction func actionMain() {
        presenter.performMainAction()
    }

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }
}

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceive(viewModel: StakingMainViewModelProtocol) {
        let sideSize = iconButtonWidth.constant - iconButton.contentInsets.left
            - iconButton.contentInsets.right
        let size = CGSize(width: sideSize, height: sideSize)
        let icon = try? iconGenerator?.generateFromAddress(viewModel.address)
            .imageWithFillColor(R.color.colorWhite()!, size: size, contentScale: UIScreen.main.scale)
        iconButton.imageWithTitleView?.iconImage = icon
        iconButton.invalidateLayout()
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        titleLabel.text = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: locale?.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .stakingStartTitle(preferredLanguages: locale?.rLanguages)
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
