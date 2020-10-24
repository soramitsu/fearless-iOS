import SoraUI

final class SubtitleActionControl: BaseActionControl {
    var imageIndicator: ImageActionIndicator! {
        indicator as? ImageActionIndicator
    }

    var showsImageIndicator: Bool {
        get {
            !imageIndicator.isHidden
        }

        set {
            imageIndicator.isHidden = !newValue
        }
    }

    var contentView: SubtitleContentView! {
        title as? SubtitleContentView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        backgroundColor = .clear

        if indicator == nil {
            indicator = ImageActionIndicator()
            indicator?.backgroundColor = .clear
            indicator?.isUserInteractionEnabled = false
        }

        if title == nil {
            title = SubtitleContentView()
            title?.isUserInteractionEnabled = false
            title?.backgroundColor = .clear
        }
    }
}
