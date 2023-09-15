import UIKit

final class NftDetailsViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.spacing = UIConstants.bigOffset
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let mediaView: UniversalMediaView = {
        let mediaView = UniversalMediaView(frame: .zero)
        mediaView.allowLooping = true
        mediaView.shouldHidePlayButton = true
        mediaView.shouldAutoPlayAfterPresentation = true
        mediaView.backgroundColor = .clear
        return mediaView
    }()

    let sendButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let desciptionLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorGray()
        label.numberOfLines = 0
        return label
    }()

    lazy var collectionView: TitleValueView = {
        let view = createTitleValueView()
        view.valueLabel.numberOfLines = 0
        return view
    }()

    lazy var ownerView: TitleCopyableValueView = {
        let view = createTitleCopyableValueView()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        return view
    }()

    lazy var tokenIdView: TitleCopyableValueView = {
        createTitleCopyableValueView()
    }()

    lazy var networkView: TitleValueView = {
        createTitleValueView()
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createTitleValueView() -> TitleValueView {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .p1Paragraph
        view.valueLabel.textColor = R.color.colorWhite()
        return view
    }

    private func createTitleCopyableValueView() -> TitleCopyableValueView {
        let view = TitleCopyableValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .p1Paragraph
        view.valueLabel.textColor = R.color.colorWhite()
        return view
    }

    private func setupSubviews() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(mediaView)
        contentView.stackView.addArrangedSubview(sendButton)
        contentView.stackView.addArrangedSubview(desciptionLabel)
        contentView.stackView.addArrangedSubview(collectionView)
        contentView.stackView.addArrangedSubview(ownerView)
        contentView.stackView.addArrangedSubview(tokenIdView)
        contentView.stackView.addArrangedSubview(networkView)

        navigationBar.setCenterViews([navigationTitleLabel])
        setupConstraints()
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.bottom.trailing.equalTo(safeAreaLayoutGuide)
        }

        mediaView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(359)
        }

        sendButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        desciptionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        collectionView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(UIConstants.cellHeight)
        }
        ownerView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
        }
        tokenIdView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
        }
        networkView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
        }
    }

    private func applyLocalization() {
        sendButton.imageWithTitleView?.title = R.string.localizable.walletSendTitle(preferredLanguages: locale.rLanguages)
        collectionView.titleLabel.text = R.string.localizable.nftCollectionTitle(preferredLanguages: locale.rLanguages)
        ownerView.titleLabel.text = R.string.localizable.nftOwnerTitle(preferredLanguages: locale.rLanguages)
        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
        tokenIdView.titleLabel.text = R.string.localizable.nftTokenidTitle(preferredLanguages: locale.rLanguages)
    }

    func bind(viewModel: NftDetailViewModel) {
        collectionView.isHidden = viewModel.collectionName == nil
        ownerView.isHidden = viewModel.owner == nil
        tokenIdView.isHidden = viewModel.tokenId == nil
        networkView.isHidden = viewModel.chain == nil

        navigationTitleLabel.text = viewModel.nftName
        collectionView.valueLabel.text = viewModel.collectionName
        ownerView.valueLabel.text = viewModel.owner
        tokenIdView.valueLabel.text = viewModel.tokenId
        networkView.valueLabel.text = viewModel.chain
        desciptionLabel.text = viewModel.nftDescription

        mediaView.bind(mediaURL: viewModel.nft.media?.first?.normalizedURL, animating: true)
    }
}
