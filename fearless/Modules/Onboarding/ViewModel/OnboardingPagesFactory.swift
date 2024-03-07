import UIKit

struct OnboardingDataSource {
    let pages: [OnboardingPageViewModel]
}

struct OnboardingPageViewModel {
    let title: String?
    let description: String?
    let imageViewModel: RemoteImageViewModel?
}

protocol OnboardingPagesFactoryProtocol {
    func createPageControllers(with configWrapper: OnboardingConfigWrapper) -> OnboardingDataSource
}

final class OnboardingPagesFactory: OnboardingPagesFactoryProtocol {
    func createPageControllers(with configWrapper: OnboardingConfigWrapper) -> OnboardingDataSource {
        let onboardingPages = configWrapper.en.new
        let pages = onboardingPages.compactMap { page in
            createViewModel(with: page)
        }
        let dataSource = OnboardingDataSource(pages: pages)
        return dataSource
    }

    func createViewModel(with pageInfo: OnboardingPageInfo) -> OnboardingPageViewModel {
        var imageViewModel: RemoteImageViewModel?
        if let url = pageInfo.image {
            imageViewModel = RemoteImageViewModel(url: url)
        }
        return OnboardingPageViewModel(
            title: pageInfo.title,
            description: pageInfo.description,
            imageViewModel: imageViewModel
        )
    }
}
