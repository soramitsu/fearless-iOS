import Foundation

struct ChainOptionsViewModel {
    let text: String
    let icon: ImageViewModelProtocol?
}

extension ChainOptionsViewModel: Equatable {
    static func == (lhs: ChainOptionsViewModel, rhs: ChainOptionsViewModel) -> Bool {
        lhs.text == rhs.text
    }
}
