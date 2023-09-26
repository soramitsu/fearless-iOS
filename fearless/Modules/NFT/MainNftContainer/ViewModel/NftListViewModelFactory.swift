import UIKit

protocol NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel]
}

final class NftListViewModelFactory: NftListViewModelFactoryProtocol {
    func buildViewModel(from collections: [NFTCollection]) -> [NftListCellModel] {
        collections.sorted(by: { collection1, collection2 in
            collection1.displayName ?? "" < collection2.displayName ?? ""
        }).compactMap { collection in
            var imageViewModel: RemoteImageViewModel?
            if let url = collection.displayThumbnailImageUrl {
                imageViewModel = RemoteImageViewModel(url: url)
            }

            return NftListCellModel(
                imageViewModel: imageViewModel,
                chainNameLabelText: collection.chain.name,
                nftNameLabelText: collection.displayName,
                priceLabelAttributedText: nil,
                collection: collection,
                nftCountLabelText: (collection.nfts?.count).map { String($0) }
            )
        }
    }

    private func createFloorPriceString(for collection: NFTCollection) -> NSAttributedString? {
        guard let price = collection.opensea?.floorPrice, let utilityChainAssetSymbol = collection.chain.utilityChainAssets().first?.asset.symbol else {
            return nil
        }

        let title = "Floor price: "
        let value = "\(price) \(utilityChainAssetSymbol.uppercased())"

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: title))
        attributed.append(NSAttributedString(string: value))
        attributed.addAttribute(.foregroundColor, value: R.color.colorGray() as Any, range: NSMakeRange(0, title.count))
        attributed.addAttribute(.font, value: UIFont.p2Paragraph, range: NSMakeRange(0, title.count))
        attributed.addAttribute(.foregroundColor, value: R.color.colorWhite() as Any, range: NSMakeRange(title.count, value.count))
        attributed.addAttribute(.font, value: UIFont.capsTitle, range: NSMakeRange(title.count, value.count))

        return attributed
    }
}
