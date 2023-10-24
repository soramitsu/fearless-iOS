import UIKit
import SoraFoundation
import SoraUI
import SSFModels

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
    private var exportSubstrateButton: TriangularedButton?
    private var exportEthereumButton: TriangularedButton?

    private var containerView: ScrollableContainerView!
    private var sourceTypeView: DetailsTriangularedView!
    private var networkView: DetailsTriangularedView?
    private var expandableControl: ExpandableActionControl!
    private var separatorView: UIView?
    private var advancedContainerViews: [UIView]?
    private var advancedContainer: UIStackView?
    private var optionViews: [UIView]?
    private var alreadyDisplayedMnemonics: [[String]]?

    private var viewModel: MultipleExportGenericViewModelProtocol?

    private var shouldShowAdvanced: Bool {
        guard let option = viewModel?.option, let flow = viewModel?.flow else {
            return true
        }
        switch (option, flow) {
        case (.mnemonic, _):
            return true
        case let (.seed, flow):
            if case let .single(chain, _, _) = flow, chain.isEthereumBased {
                return false
            }
            return true
        case (.keystore, _):
            return false
        }
    }

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
        view.backgroundColor = R.color.colorBlack19()

        setupContainerView()
        setupButtonsContainerView()

        if case let .single(chain, _, _) = presenter.flow {
            let networkView = setupNetworkView(
                chain: chain,
                locale: selectedLocale
            )
            self.networkView = networkView
        }
        setupSourceTypeView()
        setupExpandableActionView()
        setupAnimatingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()

        presenter.setup()

        setupBackButton()
        setAdvancedContainer(visibility: shouldShowAdvanced)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        presenter.didLoadView()
    }

    private func setupLocalization() {
        guard let locale = localizationManager?.selectedLocale else {
            return
        }
        switch presenter.flow {
        case .single:
            title = R.string.localizable.commonExport(preferredLanguages: locale.rLanguages)
        case .multiple:
            title = R.string.localizable.exportWallet(preferredLanguages: locale.rLanguages)
        }
        sourceTypeView.title = R.string.localizable
            .importSourcePickerTitle(preferredLanguages: locale.rLanguages)
        expandableControl.titleLabel.text = R.string.localizable
            .commonAdvanced(preferredLanguages: locale.rLanguages)

        mainActionButton?.imageWithTitleView?.title = mainOptionTitle?.value(for: locale)
        accessoryActionButton?.imageWithTitleView?.title = accessoryOptionTitle?.value(for: locale)

        updateFromViewModel(locale)
    }

    private func updateFromViewModel(_ locale: Locale) {
        alreadyDisplayedMnemonics = nil

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

        sourceTypeView.subtitle = viewModel.option.titleForLocale(locale, ethereumBased: nil)
        var views: [UIView] = []
        viewModel.viewModels.forEach { exportViewModel in
            if let view = setupExportDataView(exportViewModel) {
                views.append(view)
            }

            if viewModel.option == .keystore {
                if exportViewModel.ethereumBased {
                    setupExportEthereumButton()
                } else {
                    setupExportSubstrateButton()
                }
            } else if mainOptionTitle != nil {
                setupMainActionButton()
            }
        }

        if accessoryOptionTitle != nil {
            setupAccessoryButton()
        }

        if shouldShowAdvanced {
            setupAdvancedContainerView(with: viewModel, locale: locale)
        }

        optionViews = views

        advancedContainerViews?.forEach { view in
            view.isHidden = !expandableControl.isActivated
        }
        setAdvancedContainer(visibility: shouldShowAdvanced)
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

    @objc private func backButtonClicked() {
        navigationController?.popToRootViewController(animated: true)
    }

    @objc private func exportGestureHandler(_ sender: UITapGestureRecognizer) {
        if let view = sender.view as? MultilineTriangularedView {
            presenter.didTapStringExport(view.subtitleLabel.text)
        }
    }
}

extension ExportGenericViewController {
    private func setupBackButton() {
        let backButton = UIBarButtonItem(
            image: R.image.iconBack(),
            style: .plain,
            target: self,
            action: #selector(backButtonClicked)
        )
        navigationItem.leftBarButtonItem = backButton
    }

    private func setupButtonsContainerView() {
        view.addSubview(buttonsStackView)

        buttonsStackView.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.top.equalTo(containerView.snp.bottom).offset(UIConstants.bigOffset)
        }
    }

    private func setupMainActionButton() {
        if let mainActionButton = mainActionButton {
            buttonsStackView.removeArrangedSubview(mainActionButton)
            mainActionButton.removeFromSuperview()
        }

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

        button.imageWithTitleView?.title = mainOptionTitle?.value(for: selectedLocale)

        mainActionButton = button
    }

    private func setupExportSubstrateButton() {
        if let exportSubstrateButton = exportSubstrateButton {
            buttonsStackView.removeArrangedSubview(exportSubstrateButton)
            exportSubstrateButton.removeFromSuperview()
        }

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

        exportSubstrateButton = button
    }

    private func setupExportEthereumButton() {
        if let exportEthereumButton = exportEthereumButton {
            buttonsStackView.removeArrangedSubview(exportEthereumButton)
            exportEthereumButton.removeFromSuperview()
        }

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

        exportEthereumButton = button
    }

    private func setupAnimatingView() {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = R.color.colorBlack19()
        containerView.stackView.insertSubview(view, at: 0)

        view.leadingAnchor.constraint(equalTo: containerView.stackView.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: containerView.stackView.trailingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: sourceTypeView.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: expandableControl.bottomAnchor).isActive = true
    }

    private func setupAccessoryButton() {
        if let accessoryActionButton = accessoryActionButton {
            buttonsStackView.removeArrangedSubview(accessoryActionButton)
            accessoryActionButton.removeFromSuperview()
        }

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

        button.imageWithTitleView?.title = accessoryOptionTitle?.value(for: selectedLocale)
    }

    private func setupExportDataView(_ exportViewModel: ExportGenericViewModelProtocol) -> UIView? {
        if let mnemonicViewModel = exportViewModel as? ExportMnemonicViewModel {
            if alreadyDisplayedMnemonics?.contains(mnemonicViewModel.mnemonic) == true {
                return nil
            } else {
                if alreadyDisplayedMnemonics == nil {
                    alreadyDisplayedMnemonics = []
                }

                alreadyDisplayedMnemonics?.append(mnemonicViewModel.mnemonic)
            }
        }

        let newOptionView = exportViewModel.accept(binder: binder, locale: selectedLocale)
        newOptionView.backgroundColor = R.color.colorBlack19()!
        newOptionView.translatesAutoresizingMaskIntoConstraints = false

        #if DEBUG
            if let _ = exportViewModel as? ExportStringViewModel {
                let gesture = UITapGestureRecognizer(target: self, action: #selector(exportGestureHandler(_:)))
                newOptionView.addGestureRecognizer(gesture)
            }
        #endif

        insert(subview: newOptionView, after: sourceTypeView)

        newOptionView.widthAnchor.constraint(
            equalTo: view.widthAnchor,
            constant: -2.0 * UIConstants.horizontalInset
        ).isActive = true

        return newOptionView
    }

    private func setupContainerView() {
        containerView = ScrollableContainerView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        containerView.stackView.spacing = Constants.verticalSpacing

        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        var inset = containerView.scrollView.contentInset
        inset.top = Constants.topInset
        containerView.scrollView.contentInset = inset
    }

    private func setupSourceTypeView() {
        let view = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        view.backgroundColor = R.color.colorBlack19()!
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
        view.backgroundColor = R.color.colorBlack19()
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
        separatorView = bottomSeparator
    }

    private func setupAdvancedContainerView(
        with viewModel: MultipleExportGenericViewModelProtocol,
        locale: Locale
    ) {
        var views: [UIView] = []

        viewModel.viewModels.forEach { exportViewModel in

            let containerView = uiFactory.createVerticalStackView(spacing: 8)

            self.containerView.stackView.addArrangedSubview(containerView)

            containerView.widthAnchor.constraint(
                equalTo: view.widthAnchor,
                constant: -2.0 * UIConstants.horizontalInset
            ).isActive = true

            var subviews: [UIView] = []

            if let cryptoType = exportViewModel.cryptoType {
                let cryptoTypeView = setupCryptoTypeView(
                    cryptoType: cryptoType,
                    advancedContainerView: containerView,
                    locale: locale,
                    isEthereum: exportViewModel.ethereumBased
                )
                subviews.append(cryptoTypeView)
            }

            if let derivationPath = exportViewModel.derivationPath {
                let derivationPathView = setupDerivationView(
                    derivationPath,
                    advancedContainerView: containerView,
                    locale: locale,
                    isEthereum: exportViewModel.ethereumBased
                )
                subviews.append(derivationPathView)
            }

            _ = subviews.reduce(nil) { (_: UIView?, subview: UIView) in
                subview.heightAnchor
                    .constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true
                return subview
            }

            views.append(containerView)
        }

        advancedContainerViews = views
        expandableControl.isHidden = advancedContainerViews?.isEmpty == true
    }

    private func setupCryptoTypeView(
        cryptoType: CryptoType,
        advancedContainerView: UIStackView,
        locale: Locale,
        isEthereum: Bool
    ) -> UIView {
        let cryptoView = uiFactory.createDetailsView(with: .largeIconTitleSubtitle, filled: true)
        cryptoView.translatesAutoresizingMaskIntoConstraints = false
        advancedContainerView.addArrangedSubview(cryptoView)

        cryptoView.title = isEthereum
            ? R.string.localizable.ethereumCryptoType(preferredLanguages: locale.rLanguages)
            : R.string.localizable.substrateCryptoType(preferredLanguages: locale.rLanguages)

        cryptoView.subtitle = cryptoType.titleForLocale(locale) + " | " + cryptoType.subtitleForLocale(locale)

        return cryptoView
    }

    private func setupDerivationView(
        _ path: String,
        advancedContainerView: UIStackView,
        locale: Locale,
        isEthereum: Bool
    ) -> UIView {
        let derivationPathView = uiFactory.createDetailsView(with: .largeIconTitleSubtitle, filled: true)
        derivationPathView.translatesAutoresizingMaskIntoConstraints = false
        advancedContainerView.addArrangedSubview(derivationPathView)

        derivationPathView.title = isEthereum
            ? R.string.localizable.ethereumSecretDerivationPath(preferredLanguages: locale.rLanguages)
            : R.string.localizable.substrateSecretDerivationPath(preferredLanguages: locale.rLanguages)
        derivationPathView.subtitle = path

        return derivationPathView
    }

    private func setupNetworkView(
        chain: ChainModel,
        locale: Locale
    ) -> DetailsTriangularedView {
        let networkView = uiFactory.createDetailsView(with: .smallIconTitleSubtitle, filled: true)
        networkView.translatesAutoresizingMaskIntoConstraints = false
        containerView.stackView.addArrangedSubview(networkView)

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

        networkView.widthAnchor.constraint(
            equalTo: view.widthAnchor,
            constant: -2.0 * UIConstants.horizontalInset
        ).isActive = true

        networkView.heightAnchor.constraint(equalToConstant: UIConstants.triangularedViewHeight).isActive = true
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

    private func setAdvancedContainer(visibility: Bool) {
        advancedContainer?.isHidden = !visibility
        expandableControl.isHidden = !visibility
        separatorView?.isHidden = !visibility
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
