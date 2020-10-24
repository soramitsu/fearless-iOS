import UIKit
import SoraFoundation

final class CommingSoonViewController: UIViewController {
    var presenter: CommingSoonPresenterProtocol!

    @IBOutlet private var backgroundImageView: UIImageView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var devStatusButton: TriangularedButton!
    @IBOutlet private var roadmapButton: TriangularedButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    func setupLocalization() {
        let locale = localizationManager?.selectedLocale

        titleLabel.text = R.string.localizable
            .comingSoon(preferredLanguages: locale?.rLanguages)
        devStatusButton.imageWithTitleView?.title = R.string.localizable
            .comingSoonDevStatus(preferredLanguages: locale?.rLanguages)
        roadmapButton.imageWithTitleView?.title = R.string
            .localizable.commingSoonRoadmap(preferredLanguages: locale?.rLanguages)
    }

    @IBAction func actionDevStatus() {
        presenter.activateDevStatus()
    }

    @IBAction func actionRoadmap() {
        presenter.activateRoadmap()
    }
}

extension CommingSoonViewController: CommingSoonViewProtocol {}

extension CommingSoonViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
