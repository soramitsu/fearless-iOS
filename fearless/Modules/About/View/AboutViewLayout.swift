import UIKit
import SoraUI

final class AboutViewLayout: UIView {
    // MARK: - UI

    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconFearlessBig()
        return imageView
    }()

    private let aboutTitle: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let gradientView: GradientView = {
        let gradient = GradientView()
        gradient.startColor = .clear
        return gradient
    }()

    private let headerContainer = UIView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
        return view
    }()

    // MARK: - Locale

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        aboutTitle.text = R.string.localizable.aboutTitle(preferredLanguages: locale.rLanguages)
        setNeedsLayout()
    }

    // MARK: - Constructors

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        aboutTitle.preferredMaxLayoutWidth = max(1, width - 2 * UIConstants.bigOffset)
        let size = headerContainer.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let frame = CGRect(x: 0, y: 0, width: width, height: ceil(size.height))
        if headerContainer.frame != frame {
            headerContainer.frame = frame
            tableView.tableHeaderView = headerContainer
        }
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.tableHeaderView = headerContainer

        headerContainer.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        headerContainer.addSubview(logoImageView)
        logoImageView.snp.makeConstraints { make in
            make.width.equalTo(142)
            make.height.equalTo(61)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(24)
        }

        headerContainer.addSubview(aboutTitle)
        aboutTitle.snp.makeConstraints { make in
            make.top.equalTo(logoImageView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().offset(-UIConstants.bigOffset)
        }
    }
}
