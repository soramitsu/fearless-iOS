import UIKit
import SnapKit

final class CreateContactViewLayout: UIView {
    enum LayoutConstants {
        static let stackViewSpacing: CGFloat = 12
        static let stackSubviewHeight: CGFloat = 64
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backButton.rounded()
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    let networkView = UIFactory.default.createNetworkView(selectable: false)
    let contactNameField = TriangularedTextField()
    let contactAddressField: TriangularedTextField = {
        let view = TriangularedTextField()
        if let oldStyle = view.textField.defaultTextAttributes[
            .paragraphStyle,
            default: NSParagraphStyle()
        ] as? NSParagraphStyle,
            let style: NSMutableParagraphStyle = oldStyle.mutableCopy() as? NSMutableParagraphStyle {
            style.lineBreakMode = .byTruncatingMiddle
            view.textField.defaultTextAttributes[.paragraphStyle] = style
        }
        return view
    }()

    private let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let createButton: TriangularedButton = {
        let button = TriangularedButton()
        button.set(enabled: false)
        return button
    }()

    var keyboardAdoptableConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    func bind(viewModel: CreateContactViewModel) {
        contactAddressField.textField.text = viewModel.address
        networkView.subtitle = viewModel.chainName
        viewModel.iconViewModel?.cancel(on: networkView.iconView)
        networkView.iconView.image = nil
        viewModel.iconViewModel?.loadAmountInputIcon(on: networkView.iconView, animated: true)
    }

    func updateState(isValid: Bool) {
        createButton.set(enabled: isValid)
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(createButton)

        contentView.stackView.addArrangedSubview(networkView)
        contentView.stackView.addArrangedSubview(contactNameField)
        contentView.stackView.addArrangedSubview(contactAddressField)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(createButton.snp.top).offset(-UIConstants.bigOffset)
        }

        networkView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contactNameField.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contactAddressField.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.stackSubviewHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        createButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        createButton.imageWithTitleView?.title = R.string.localizable.contactsCreateContact(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.contactsCreateContact(
            preferredLanguages: locale.rLanguages
        ))
        contactNameField.textField.placeholder = R.string.localizable.contactsContactName(
            preferredLanguages: locale.rLanguages
        )
        contactAddressField.textField.placeholder = R.string.localizable.contactsContactAddress(
            preferredLanguages: locale.rLanguages
        )
        networkView.title = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
    }
}
