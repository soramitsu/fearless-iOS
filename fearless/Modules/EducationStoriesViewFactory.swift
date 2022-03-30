import Foundation
import UIKit

enum EducationStoriesKeys: String {
    case newsVersion2
}

protocol EducationStoriesFactory {
    func createNewsVersion2Stories(for locale: Locale) -> [EducationSlideView]
}

final class EducationStoriesFactoryImpl: EducationStoriesFactory {
    func createNewsVersion2Stories(for locale: Locale) -> [EducationSlideView] {
        let newsVersion2Stories = NewsVersion2.allCases.map { slide -> EducationSlideView in
            let rLanguages = locale.rLanguages

            switch slide {
            case .slide1:
                return createSlide(
                    with: R.string.localizable.storiesVersion2Slide1Title(preferredLanguages: rLanguages),
                    description: R.string.localizable.storiesVersion2Slide1Subtitle(preferredLanguages: rLanguages),
                    image: R.image.newsVersion2Slide1(),
                    imageViewContentMode: .scaleAspectFill
                )
            case .slide2:
                return createSlide(
                    with: R.string.localizable.storiesVersion2Slide2Title(preferredLanguages: rLanguages),
                    description: R.string.localizable.storiesVersion2Slide2Subtitle(preferredLanguages: rLanguages),
                    image: R.image.newsVersion2Slide2(),
                    imageViewContentMode: .scaleAspectFill
                )
            case .slide3:
                return createSlide(
                    with: R.string.localizable.storiesVersion2Slide3Title(preferredLanguages: rLanguages),
                    description: R.string.localizable.storiesVersion2Slide3Subtitle(preferredLanguages: rLanguages),
                    image: R.image.newsVersion2Slide3(),
                    imageViewContentMode: .scaleAspectFit
                )
            case .slide4:
                return createSlide(
                    with: R.string.localizable.storiesVersion2Slide4Title(preferredLanguages: rLanguages),
                    description: R.string.localizable.storiesVersion2Slide4Subtitle(preferredLanguages: rLanguages),
                    image: UIImage(named: "newsVersion2Slide4-\(rLanguages?.first ?? "")"),
                    imageViewContentMode: .scaleAspectFit
                )
            case .slide5:
                return createSlide(
                    with: R.string.localizable.storiesVersion2Slide5Title(preferredLanguages: rLanguages),
                    description: R.string.localizable.storiesVersion2Slide5Subtitle(preferredLanguages: rLanguages),
                    image: UIImage(named: "newsVersion2Slide5-\(rLanguages?.first ?? "")"),
                    imageViewContentMode: .top
                )
            }
        }

        return newsVersion2Stories
    }

    private func createSlide(
        with title: String,
        description: String,
        image: UIImage?,
        imageViewContentMode: UIView.ContentMode
    ) -> EducationSlideView {
        let view = EducationStoriesSlideView(
            title: title,
            descriptionTitle: description,
            image: image,
            imageViewContentMode: imageViewContentMode
        )
        return view
    }
}

// MARK: - Stories slides

private enum NewsVersion2: CaseIterable {
    case slide1
    case slide2
    case slide3
    case slide4
    case slide5
}
