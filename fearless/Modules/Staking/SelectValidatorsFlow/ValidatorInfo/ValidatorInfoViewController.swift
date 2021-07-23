import UIKit
import SoraFoundation

final class ValidatorInfoViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorInfoViewLayout

    let presenter: ValidatorInfoPresenterProtocol

    struct LinkPair {
        let view: UIView
        let item: ValidatorInfoViewModel.IdentityItem
    }

    private var linkPairs: [LinkPair] = []

    // MARK: Lifecycle -

    init(presenter: ValidatorInfoPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ValidatorInfoViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        presenter.setup()
    }

    private func setupLocalization() {
        title = R.string.localizable
            .stakingValidatorInfoTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    func apply(viewModel: ValidatorInfoViewModel) {
        rootView.clearStackView()
        linkPairs = []

        let sectionSpacing: CGFloat = 25.0
        let accountView = rootView.addAccountView(for: viewModel.account)
        rootView.stackView.setCustomSpacing(sectionSpacing, after: accountView)

        accountView.addTarget(self, action: #selector(actionOnAccount), for: .touchUpInside)

        rootView.addSectionHeader(
            with: R.string.localizable.stakingTitle(preferredLanguages: selectedLocale.rLanguages)
        )
        rootView.addStakingStatusView(viewModel.staking, locale: selectedLocale)

        if case let .elected(exposure) = viewModel.staking.status {
            rootView.addNominatorsView(exposure, locale: selectedLocale)

            let totalStakeView = rootView.addTotalStakeView(exposure, locale: selectedLocale)
            totalStakeView.addTarget(self, action: #selector(actionOnTotalStake), for: .touchUpInside)

            rootView.addTitleValueView(
                for: R.string.localizable.stakingValidatorEstimatedReward(
                    preferredLanguages: selectedLocale.rLanguages
                ),
                value: exposure.estimatedReward
            )
        }

        if let identityItems = viewModel.identity, !identityItems.isEmpty {
            rootView.stackView.arrangedSubviews.last.map { lastView in
                rootView.stackView.setCustomSpacing(sectionSpacing, after: lastView)
            }

            rootView.addSectionHeader(
                with: R.string.localizable.identityTitle(preferredLanguages: selectedLocale.rLanguages)
            )

            identityItems.forEach { item in
                switch item.value {
                case let .link(value, _):
                    addLinkView(for: item, title: item.title, value: value)
                case let .text(text):
                    rootView.addTitleValueView(for: item.title, value: text)
                }
            }
        }
    }

    private func addLinkView(for item: ValidatorInfoViewModel.IdentityItem, title: String, value: String) {
        let itemView = rootView.addLinkView(for: title, url: value)
        linkPairs.append(LinkPair(view: itemView, item: item))

        itemView.addTarget(
            self,
            action: #selector(actionOnIdentityLink(_:)),
            for: .touchUpInside
        )
    }

    @objc private func actionOnAccount() {
        presenter.presentAccountOptions()
    }

    @objc private func actionOnTotalStake() {
        presenter.presentTotalStake()
    }

    @objc private func actionOnIdentityLink(_ sender: UIControl) {
        guard let linkPair = linkPairs.first(where: { $0.view === sender }) else {
            return
        }

        presenter.presentIdentityItem(linkPair.item.value)
    }
}

// MARK: - ValidatorInfoViewProtocol

extension ValidatorInfoViewController: ValidatorInfoViewProtocol {
    func didRecieve(viewModel: ValidatorInfoViewModel) {
        apply(viewModel: viewModel)
    }
}

// MARK: - Localizable

extension ValidatorInfoViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
