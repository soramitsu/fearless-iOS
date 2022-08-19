import Foundation

struct ChainOptionsViewModel {
    let text: String
    let icon: ImageViewModelProtocol?
}

extension ChainOptionsViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }

    static func == (lhs: ChainOptionsViewModel, rhs: ChainOptionsViewModel) -> Bool {
        lhs.text == rhs.text
    }
}
