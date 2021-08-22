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

        setupEmbeddedModules()
        configureSegmentedControl()
        applyLocalization()
        rootView.horizontalScrollView.delegate = self
    }

    private func configureSegmentedControl() {
        rootView.segmentedControl.configure()
        rootView.segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
    }

    @objc
    private func segmentedControlChanged() {
        let selectedSegmentIndex = rootView.segmentedControl.selectedSegmentIndex
        rootView.horizontalScrollView.scrollTo(horizontalPage: selectedSegmentIndex, animated: true)
    }

    private func setupEmbeddedModules() {
        var lastView: UIView?

        for module in embeddedModules {
            let controller = module.controller
            addChild(controller)
            let view = controller.view!
            rootView.horizontalScrollView.addSubview(view)

            view.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(rootView)

                if let leftView = lastView {
                    make.left.equalTo(leftView.snp.right)
                } else {
                    make.left.equalTo(rootView.horizontalScrollView)
                }
            }
            controller.didMove(toParent: self)

            lastView = view
        }

        lastView?.snp.makeConstraints { make in
            make.height.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }
}

extension AnalyticsContainerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable.stakingAnalyticsTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.segmentedControl.titles = embeddedModules.map { $0.localizedTitle.value(for: selectedLocale) }
        }
    }
}

extension AnalyticsContainerViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let indexOfPage = Int(scrollView.contentOffset.x / scrollView.frame.size.width)
        rootView.segmentedControl.selectedSegmentIndex = indexOfPage
    }
}
