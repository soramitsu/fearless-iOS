import Foundation
import SoraFoundation

protocol StoriesFactoryProtocol {
    static func createModel() -> LocalizableResource<StoriesModel>
}

final class StoriesFactory {}

extension StoriesFactory: StoriesFactoryProtocol {
    static func createModel() -> LocalizableResource<StoriesModel> {
        LocalizableResource { locale in
            let slides1 = [
                StorySlide(
                    description: R.string.localizable.stakingStoryStakingPage1(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-staking"
                ),

                StorySlide(
                    description: R.string.localizable.stakingStoryStakingPage2(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-staking"
                )
            ]

            let slides2 = [
                StorySlide(
                    description: R.string.localizable.stakingStoryNominatorPage1(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-nominator"
                ),
                StorySlide(
                    description: R.string.localizable.stakingStoryNominatorPage2(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-nominator"
                )
            ]

            let slides3 = [
                StorySlide(
                    description: R.string.localizable.stakingStoryValidatorPage1(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-validator"
                ),

                StorySlide(
                    description: R.string.localizable.stakingStoryValidatorPage2(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-validator"
                )
            ]

            let slides4 = [
                StorySlide(
                    description: R.string.localizable.stakingStoryRewardPage1(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-simple-payouts"
                ),

                StorySlide(
                    description: R.string.localizable.stakingStoryRewardPage2(preferredLanguages: locale.rLanguages),
                    urlString: "https://wiki.polkadot.network/docs/learn-simple-payouts"
                )
            ]
            // swiftlint:enable line_length

            let story1 = Story(
                icon: "💰",
                title: R.string.localizable.stakingStoryStakingTitle(preferredLanguages: locale.rLanguages),
                slides: slides1
            )
            let story2 = Story(
                icon: "💎",
                title: R.string.localizable.stakingStoryNominatorTitle(preferredLanguages: locale.rLanguages),
                slides: slides2
            )
            let story3 = Story(
                icon: "⛏",
                title: R.string.localizable.stakingStoryValidatorTitle(preferredLanguages: locale.rLanguages),
                slides: slides3
            )
            let story4 = Story(
                icon: "🎁",
                title: R.string.localizable.stakingStoryRewardTitle(preferredLanguages: locale.rLanguages),
                slides: slides4
            )

            return StoriesModel(stories: [story1, story2, story3, story4])
        }
    }
}
