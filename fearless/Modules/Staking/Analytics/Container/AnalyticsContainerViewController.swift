import UIKit
import SoraFoundation

final class AnalyticsContainerViewController: UIViewController, ViewHolder, AnalyticsContainerViewProtocol {
    typealias RootViewType = AnalyticsContainerViewLayout

    let embeddedModules: [AnalyticsEmbeddedViewProtocol]

    init(
        embeddedModules: [AnalyticsEmbeddedViewProtocol],
        localizationManager: LocalizationManager? = nil
    ) {
        self.embeddedModules = embeddedModules
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AnalyticsContainerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Analytics"
        setupEmbeddedModules()
        configureSegmentedControl()
        rootView.horizontalScrollView.delegate = self
    }

    private func configureSegmentedControl() {
        rootView.segmentedControl.configure()
        rootView.segmentedControl.titles = embeddedModules.map { $0.localizedTitle.value(for: selectedLocale) }
        rootView.segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
    }

    @objc
    private func segmentedControlChanged() {
        let selectedSegmentIndex = rootView.segmentedControl.selectedSegmentIndex
        rootView.horizontalScrollView.scrollTo(horizontalPage: selectedSegmentIndex, animated: true)
    }

    private func setupEmbeddedModules() {
        embeddedModules.forEach { module in
            let controller = module.controller
            addChild(controller)
            let view = controller.view!
            rootView.embeddedModulesStackView.addArrangedSubview(view)
            view.snp.makeConstraints {
                $0.width.equalTo(rootView)
            }
            controller.didMove(toParent: self)
        }
    }
}

extension AnalyticsContainerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            // TODO:
        }
    }
}

extension AnalyticsContainerViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let indexOfPage = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        rootView.segmentedControl.selectedSegmentIndex = indexOfPage
    }
}
