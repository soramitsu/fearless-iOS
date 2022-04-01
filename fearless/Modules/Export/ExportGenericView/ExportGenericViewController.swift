import UIKit
import SoraFoundation
import SoraUI

final class ExportGenericViewController: UIViewController, ImportantViewProtocol {
    private enum Constants {
        static let verticalSpacing: CGFloat = 16.0
        static let topInset: CGFloat = 12.0
    }

    var presenter: ExportGenericPresenterProtocol!

    let accessoryOptionTitle: LocalizableResource<String>?
    let mainOptionTitle: LocalizableResource<String>?
    let binder: ExportGenericViewModelBinding
    let uiFactory: UIFactoryProtocol

    private var buttonsStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)
        stackView.distribution = .equalSpacing
        return stackView
    }()

    private var mainActionButton: TriangularedButton?
    private var secondaryActionButton: TriangularedButton?
    private var accessoryActionButton: TriangularedButton?

    private var containerView: ScrollableContainerView!
    private var sourceTypeView: DetailsTriangularedView!
    private var expandableControl: ExpandableActionControl!
    private var advancedContainerViews: [UIView]?
    private var optionViews: [UIView]?

    private var viewModel: MultipleExportGenericViewModelProtocol?

    var advancedAppearanceAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromBottom,
        curve: .easeOut
    )

    var advancedDismissalAnimator = TransitionAnimator(
        type: .push,
        duration: 0.35,
        subtype: .fromTop,
        curve: .easeIn
    )

    init(
        uiFactory: UIFactoryProtocol,
        binder: ExportGenericViewModelBinding,
        mainTitle: LocalizableResource<String>?,
        accessoryTitle: LocalizableResource<String>?
    ) {
        self.uiFactory = uiFactory
        self.binder = binder
        mainOptionTitle = mainTitle
        accessoryOptionTitle = accessoryTitle

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = R.color.colorBlack()

        if accessoryOptionTitle != nil {
            setupAccessoryButton()
        }

        setupButtonsContainerView()
        setupContainerView()

        setupSourceTypeView()
        setupExpandableActionView()
        setupAnimatingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        guard let locale = localizationManager?.selectedLocale else {
            return
        }

        title = R.string.localizable.commonExport(preferredLanguages: locale.rLanguages)
        sourceTypeView.title = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)
        expandableControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)

        mainActionButton?.imageWithTitleView?.title = mainOptionTitle?.value(for: locale)
        accessoryActionButton?.imageWithTitleView?.title = accessoryOptionTitle?.value(for: locale)

        updateFromViewModel(locale)
    }

    private func updateFromViewModel(_ locale: Locale) {
        guard let viewModel = viewModel else {
            return
        }

        optionViews?.forEach { view in
            containerView.stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        advancedContainerViews?.forEach { view in
            containerView.stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        var views: [UIView] = []
        viewModel.viewModels.forEach { exportViewModel in
            sourceTypeView.subtitle = exportViewModel.option.titleForLocale(locale, ethereumBased: nil)

            let newOptionView = exportViewModel.accept(binder: binder, locale: locale)
            newOptionView.backgroundColor = R.color.colorBlack()!
            newOptionView.translatesAutoresizingMaskIntoConstraints = false

            insert(subview: newOptionView, after: sourceTypeView)

            newOptionView.widthAnchor.constraint(
                equalTo: view.widthAnchor,
                constant: -2.0 * UIConstants.horizontalInset
            ).isActive = true

            views.append(newOptionView)

            if exportViewModel.option == .keystore {
                if exportViewModel.ethereumBased {
                    setupExportEthereumButton()
                } else {
                    setupExportSubstrateButton()
                }
            } else {
                if mainOptionTitle != nil {
                    setupMainActionButton()
                }
            }
        }

        setupAdvancedContainerView(with: viewModel, locale: locale)

        optionViews = views

        advancedContainerViews?.forEach { view in
            view.isHidden = !expandableControl.isActivated
        }
    }

    @objc private func actionMain() {
        presenter.activateExport()
    }

    @objc private func actionAccessory() {
        presenter.activateAccessoryOption()
    }

    @objc private func actionToggleExpandableControl() {
        advancedContainerViews?.forEach { advancedContainerView in
            containerView.stackView.sendSubviewToBack(advancedContainerView)

            advancedContainerView.isHidden = !expandableControl.isActivated

            if expandableControl.isActivated {
                advancedAppearanceAnimator.animate(view: advancedContainerView, completionBlock: nil)
            } else {
                advancedDismissalAnimator.animate(view: advancedContainerView, completionBlock: nil)
            }
        }
    }

    @objc private func exportSubstrateButtonClicked() {
        presenter.didTapExportSubstrateButton()
    }

    @objc private func exportEthereumButtonClicked() {
        presenter.didTapExportEthereumButton()
    }
}

extension ExportGenericViewController {
    private func setupButtonsContainerView() {
        view.addSubview(buttonsStackView)

        buttonsStackView.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }
    }

    private func setupMainActionButton() {
        let button = uiFactory.createMainActionButton()
        buttonsStackView.addArrangedSubview(button)

        button.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        button.addTarget(
            self,
            action: #selector(actionMain),
            for: .touchUpInside
        )

        mainActionButton = button
    }

    private func setupExportSubstrateButton() {
        let button = uiFactory.createMainActionButton()
        buttonsStackView.addArrangedSubview(button)

        button.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        button.addTarget(
            self,
            action: #selector(exportSubstrateButtonClicked),
            for: .touchUpInside
        )

        button.imageWithTitleView?.title = R.string.localizable.exportSubstrateTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupExportEthereumButton() {
        let button = uiFactory.createMainActionButton()
        buttonsStackView.addArrangedSubview(button)

        button.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        button.addTarget(
            self,
            action: #selector(exportEthereumButtonClicked),
            for: .touchUpInside
        )

        button.imageWithTitleView?.title = R.string.localizable.exportEthereumTitle(preferredLanguages: selectedLocale.rLanguages)
    }

    private func setupAnimatingView() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.colorBlack()
        containerView.stackView.insertSubview(view, at: 0)

        view.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: containerView.stackView.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: sourceTypeView.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: expandableControl.bottomAnchor).isActive = true
    }

    private func setupAccessoryButton() {
        let button = uiFactory.createAccessoryButton()
        buttonsStackView.addArrangedSubview(button)
        button.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
        }

        button.addTarget(
            self,
            action: #selector(actionAccessory),
            for: .touchUpInside
        )

        accessoryActionButton = button
    }

    private func setupContainerView() {
        containerView = ScrollableContainerView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        containerView.stackView.spacing = Constants.verticalSpacing

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(buttonsStackView.snp.top)
        }

        var inset = containerView.scrollView.contentInset
        inset.top = Constants.topInset
        containerView.scrollView.contentInset = inset
    }

    private func setupSourceTypeView() {
        let view = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        view.backgroundColor = R.color.colorBlack()!
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.stackView.addArrangedSubview(view)
        containerView.stackView.setCustomSpacing(Constants.verticalSpacing, after: view)

        view.widthAnchor.constraint(
            equalTo: self.view.widthAnchor,
            constant: -2.0 * UIConstants.horizontalInset
        ).isActive = true

        view.heightAnchor.constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true

        sourceTypeView = view
    }

    private func setupExpandableActionView() {
        let view = uiFactory.createExpandableActionControl()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.stackView.addArrangedSubview(view)

        containerView.stackView.setCustomSpacing(0.0, after: view)

        view.widthAnchor.constraint(
            equalTo: self.view.widthAnchor,
            constant: -2.0 * UIConstants.horizontalInset
        ).isActive = true

        view.heightAnchor.constraint(equalToConstant: UIConstants.expandableViewHeight).isActive = true

        view.addTarget(
            self,
            action: #selector(actionToggleExpandableControl),
            for: .touchUpInside
        )

        expandableControl = view

        let bottomSeparator = uiFactory.createSeparatorView()
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = false
        containerView.stackView.addArrangedSubview(bottomSeparator)

        bottomSeparator.widthAnchor.constraint(
            equalTo: self.view.widthAnchor,
            constant: -2.0 * UIConstants.horizontalInset
        ).isActive = true
        bottomSeparator.heightAnchor.constraint(equalToConstant: UIConstants.formSeparatorWidth).isActive = true
    }

    private func setupAdvancedContainerView(
        with viewModel: MultipleExportGenericViewModelProtocol,
        locale: Locale
    ) {
        var views: [UIView] = []

        viewModel.viewModels.forEach { exportViewModel in
            guard let cryptoType = exportViewModel.cryptoType else {
                return
            }

            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false

            self.containerView.stackView.addArrangedSubview(containerView)

            containerView.widthAnchor.constraint(
                equalTo: view.widthAnchor,
                constant: -2.0 * UIConstants.horizontalInset
            ).isActive = true

            let cryptoTypeView = setupCryptoTypeView(
                cryptoType: cryptoType,
                advancedContainerView: containerView,
                locale: locale
            )

            var subviews = [cryptoTypeView]

            if let derivationPath = exportViewModel.derivationPath {
                let derivationPathView = setupDerivationView(
                    derivationPath,
                    advancedContainerView: containerView,
                    locale: locale
                )
                subviews.append(derivationPathView)
            }

            views.append(containerView)

            _ = subviews.reduce(nil) { (anchorView: UIView?, subview: UIView) in
                subview.leadingAnchor
                    .constraint(equalTo: containerView.leadingAnchor, constant: 0.0).isActive = true
                subview.trailingAnchor
                    .constraint(equalTo: containerView.trailingAnchor, constant: 0.0).isActive = true
                subview.heightAnchor
                    .constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true

                if let anchorView = anchorView {
                    subview.topAnchor
                        .constraint(
                            equalTo: anchorView.bottomAnchor,
                            constant: Constants.verticalSpacing
                        ).isActive = true
                } else {
                    subview.topAnchor
                        .constraint(equalTo: containerView.topAnchor).isActive = true
                }

                return subview
            }

            if let chain = exportViewModel.chain {
                let networkTypeView = setupNetworkView(
                    chain: chain,
                    advancedContainerView: containerView,
                    locale: locale
                )

                subviews.append(networkTypeView)

                containerView.bottomAnchor.constraint(
                    equalTo: networkTypeView.bottomAnchor,
                    constant: Constants.verticalSpacing
                ).isActive = true
            }
        }

        advancedContainerViews = views
        expandableControl.isHidden = advancedContainerViews?.isEmpty == true
    }

    private func setupCryptoTypeView(
        cryptoType: CryptoType,
        advancedContainerView: UIView,
        locale: Locale
    ) -> UIView {
        let cryptoView = uiFactory.createDetailsView(with: .largeIconTitleSubtitle, filled: true)
        cryptoView.translatesAutoresizingMaskIntoConstraints = false
        advancedContainerView.addSubview(cryptoView)

        cryptoView.title = R.string.localizable
            .commonCryptoType(preferredLanguages: locale.rLanguages)

        cryptoView.subtitle = cryptoType.titleForLocale(locale) + " | " + cryptoType.subtitleForLocale(locale)

        return cryptoView
    }

    private func setupDerivationView(
        _ path: String,
        advancedContainerView: UIView,
        locale: Locale
    ) -> UIView {
        let derivationPathView = uiFactory.createDetailsView(with: .largeIconTitleSubtitle, filled: true)
        derivationPathView.translatesAutoresizingMaskIntoConstraints = false
        advancedContainerView.addSubview(derivationPathView)

        derivationPathView.title = R.string.localizable
            .commonSecretDerivationPath(preferredLanguages: locale.rLanguages)
        derivationPathView.subtitle = path

        return derivationPathView
    }

    private func setupNetworkView(
        chain: ChainModel,
        advancedContainerView: UIView,
        locale: Locale
    ) -> UIView {
        let networkView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        networkView.translatesAutoresizingMaskIntoConstraints = false
        advancedContainerView.addSubview(networkView)

        networkView.title = R.string.localizable
            .commonNetwork(preferredLanguages: locale.rLanguages)
        networkView.subtitle = chain.name
        if let iconUrl = chain.icon {
            let remoteImage = RemoteImageViewModel(url: iconUrl)
            remoteImage.loadBalanceListIcon(
                on: networkView.iconView,
                animated: false
            )
        }

        return networkView
    }

    private func insert(subview: UIView, after view: UIView) {
        guard let index = containerView.stackView.arrangedSubviews
            .firstIndex(where: { $0 === view })
        else {
            return
        }

        containerView.stackView.insertArrangedSubview(subview, at: index + 1)
    }
}

extension ExportGenericViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension ExportGenericViewController: ExportGenericViewProtocol {
    func set(viewModel: MultipleExportGenericViewModelProtocol) {
        self.viewModel = viewModel

        guard let locale = localizationManager?.selectedLocale else {
            return
        }

        updateFromViewModel(locale)
    }
}
