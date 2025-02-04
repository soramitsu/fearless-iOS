import UIKit

final class ImageMarkedLabel: UIView {
    let label: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = .white
        return label
    }()
    
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func addSubviews() {
        addSubview(label)
        addSubview(imageView)
    }
    
    private func setupConstraints() {
        label.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.bottom.equalTo(label).offset(8)
            make.trailing.equalTo(label).offset(12)
            make.bottom.trailing.equalToSuperview()
            make.size.equalTo(16)
        }
    }
    
    func bind(viewModel: ImageMarkedLabelViewModel) {
        label.text = viewModel.labelText
        
        viewModel.imageViewModel?.loadImage(
            on: imageView,
            placholder: nil,
            targetSize: CGSize(width: 16, height: 16),
            animated: true
        )
    }
}
