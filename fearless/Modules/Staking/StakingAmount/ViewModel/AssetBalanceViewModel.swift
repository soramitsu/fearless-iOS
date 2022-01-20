import UIKit

protocol AssetBalanceViewModelProtocol {
    var symbol: String { get }
    var balance: String? { get }
    var price: String? { get }
    var iconViewModel: ImageViewModelProtocol? { get }
}

extension AssetBalanceViewModelProtocol {
    @available(*, deprecated, message: "Use iconViewModel instead")
    var icon: UIImage? { nil }
}

struct AssetBalanceViewModel: AssetBalanceViewModelProtocol {
    let symbol: String
    let balance: String?
    let price: String?
    let iconViewModel: ImageViewModelProtocol?
}

extension ImageViewModelProtocol {
    func loadAmountInputIcon(on imageView: UIImageView, animated _: Bool) {
        loadImage(on: imageView, targetSize: CGSize(width: 24.0, height: 24.0), animated: true)
    }

    func loadAssetInfoIcon(on imageView: UIImageView, animated _: Bool) {
        loadImage(on: imageView, targetSize: CGSize(width: 32.0, height: 32.0), animated: true)
    }

    func loadBalanceListIcon(on imageView: UIImageView, animated _: Bool) {
        loadImage(on: imageView, targetSize: CGSize(width: 48.0, height: 48.0), animated: true)
    }
}
