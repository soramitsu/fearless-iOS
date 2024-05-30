import Foundation
import SoraUI

public protocol FeeViewProtocol: AnyObject {
    var borderType: BorderType { get set }

    func bind(viewModel: FeeViewModelProtocol)
}

public typealias BaseFeeView = UIView & FeeViewProtocol

public enum FeeViewDisplayStyle {
    case singleTitle
    case separatedDetails
}

final class FeeView: BaseFeeView {
    private(set) var titleLabel = UILabel()
    private(set) var detailsLabel: UILabel?
    private(set) var editingIconImageView: UIImageView?
    private(set) var activityIndicator = UIActivityIndicatorView()
    private(set) var borderedView = BorderedContainerView()

    private(set) var viewModel: FeeViewModelProtocol?

    var borderType: BorderType {
        get {
            borderedView.borderType
        }

        set {
            borderedView.borderType = newValue
        }
    }

    var displayType: FeeViewDisplayStyle = .singleTitle {
        didSet {
            applyViewModel()
        }
    }

    var editIndicatorIcon: UIImage? {
        didSet {
            editingIconImageView?.image = editIndicatorIcon

            invalidateLayout()
        }
    }

    var detailsColor: UIColor? {
        didSet {
            detailsLabel?.textColor = detailsColor
        }
    }

    var detailsFont: UIFont? {
        didSet {
            detailsLabel?.font = detailsFont

            invalidateLayout()
        }
    }

    var contentInsets = UIEdgeInsets.zero {
        didSet {
            invalidateLayout()
        }
    }

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        addSubview(borderedView)
        addSubview(titleLabel)

        activityIndicator.hidesWhenStopped = true
        addSubview(activityIndicator)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: FeeViewModelProtocol) {
        self.viewModel = viewModel

        applyViewModel()
    }

    // MARK: Overriding

    override var intrinsicContentSize: CGSize {
        var size = CGSize(width: UIView.noIntrinsicMetric, height: 0.0)

        size.height = max(size.height, titleLabel.intrinsicContentSize.height)
        size.height = max(size.height, activityIndicator.intrinsicContentSize.height)

        if let detailsLabel = detailsLabel {
            size.height = max(size.height, detailsLabel.intrinsicContentSize.height)
        }

        if let editingImageView = editingIconImageView {
            size.height = max(size.height, editingImageView.intrinsicContentSize.height)
        }

        if size.height > 0.0 {
            size.height += contentInsets.top + contentInsets.bottom
        }

        return size
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        borderedView.frame = CGRect(origin: .zero, size: CGSize(width: bounds.width, height: bounds.height))

        layoutEditingImageViewIfNeeded()
        layoutDetailsLabelIfNeeded()
        layoutTitleLabel()
        layoutActivityIndicator()
    }

    private func layoutEditingImageViewIfNeeded() {
        guard let imageView = editingIconImageView else {
            return
        }

        let imageSize = imageView.intrinsicContentSize
        let centerOffset = (contentInsets.top - contentInsets.bottom) / 2.0

        imageView.frame = CGRect(
            x: bounds.size.width - contentInsets.right - imageSize.width,
            y: bounds.height / 2.0 - imageSize.height / 2.0 + centerOffset,
            width: imageSize.width,
            height: imageSize.height
        )
    }

    private func layoutDetailsLabelIfNeeded() {
        guard let detailsLabel = detailsLabel else {
            return
        }

        let detailsSize = detailsLabel.intrinsicContentSize

        var originX = bounds.width - contentInsets.right - detailsSize.width

        if let imageView = editingIconImageView {
            originX -= imageView.frame.size.width + horizontalSpacing
        }

        let centerOffset = (contentInsets.top - contentInsets.bottom) / 2.0

        detailsLabel.frame = CGRect(
            x: originX,
            y: bounds.height / 2.0 - detailsSize.height / 2.0 + centerOffset,
            width: detailsSize.width,
            height: detailsSize.height
        )
    }

    private func layoutTitleLabel() {
        let rightConstraint: CGFloat

        if let detailsLabel = detailsLabel {
            rightConstraint = detailsLabel.frame.minX - horizontalSpacing
        } else if let editingImageView = editingIconImageView {
            rightConstraint = editingImageView.frame.minX - horizontalSpacing
        } else {
            rightConstraint = bounds.width - contentInsets.right
        }

        let titleSize = titleLabel.intrinsicContentSize

        let centerOffset = (contentInsets.top - contentInsets.bottom) / 2.0

        titleLabel.frame = CGRect(
            x: contentInsets.left,
            y: bounds.height / 2.0 - titleSize.height / 2.0 + centerOffset,
            width: rightConstraint - contentInsets.left,
            height: titleSize.height
        )
    }

    private func layoutActivityIndicator() {
        let activitySize = activityIndicator.intrinsicContentSize

        let centerOffset = (contentInsets.top - contentInsets.bottom) / 2.0

        switch displayType {
        case .singleTitle:
            let originX = titleLabel.frame.minX + titleLabel.intrinsicContentSize.width + horizontalSpacing
            activityIndicator.frame = CGRect(
                x: originX,
                y: bounds.height / 2.0 - activitySize.height / 2.0 + centerOffset,
                width: activitySize.width,
                height: activitySize.height
            )
        case .separatedDetails:
            let originX: CGFloat

            if let editingImageView = editingIconImageView {
                originX = editingImageView.frame.minX - horizontalSpacing - activitySize.width
            } else {
                originX = bounds.size.width - contentInsets.right - activitySize.width
            }

            activityIndicator.frame = CGRect(
                x: originX,
                y: bounds.height / 2.0 - activitySize.height / 2.0 + centerOffset,
                width: activitySize.width,
                height: activitySize.height
            )
        }
    }

    // MARK: Private

    private func invalidateLayout() {
        invalidateIntrinsicContentSize()

        if superview != nil {
            setNeedsLayout()
        }
    }

    private func applyViewModel() {
        guard let viewModel = viewModel else {
            return
        }

        let title: String
        let details: String

        switch displayType {
        case .singleTitle:
            title = !viewModel.details.isEmpty ? "\(viewModel.title) \(viewModel.details)" : viewModel.title
            details = ""
        case .separatedDetails:
            title = viewModel.title
            details = viewModel.details
        }

        titleLabel.text = title

        if !details.isEmpty {
            addDetailsLabelIfNeeded()

            detailsLabel?.text = details
        } else {
            detailsLabel?.removeFromSuperview()
            detailsLabel = nil
        }

        if viewModel.allowsEditing {
            addEditingImageViewIfNeeded()
        } else {
            editingIconImageView?.removeFromSuperview()
            editingIconImageView = nil
        }

        if viewModel.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        detailsLabel?.isHidden = viewModel.isLoading

        invalidateLayout()
    }

    private func addDetailsLabelIfNeeded() {
        guard detailsLabel == nil else {
            return
        }

        let detailsLabel = UILabel()
        detailsLabel.font = detailsFont
        detailsLabel.textColor = detailsColor
        addSubview(detailsLabel)

        self.detailsLabel = detailsLabel
    }

    private func addEditingImageViewIfNeeded() {
        guard editingIconImageView == nil else {
            return
        }

        let editingImageView = UIImageView()
        editingImageView.image = editIndicatorIcon

        addSubview(editingImageView)

        editingIconImageView = editingImageView
    }
}
