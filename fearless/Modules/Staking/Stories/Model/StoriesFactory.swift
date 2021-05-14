import Foundation

protocol StoriesFactoryProtocol {
    static func createModel() -> StoriesModel
}

final class StoriesFactory {}

extension StoriesFactory: StoriesFactoryProtocol {
    static func createModel() -> StoriesModel {
        // swiftlint:disable line_length
        let slides1 = [
            StorySlide(
                description: "Staking is an option to earn passive income by locking your tokens in the network. Rewards for staking are paid every 6 hours on Kusama and 24 hours on Polkadot. You can stake as long as you wish, and for unlocking your tokens you need to wait for the unlocking period to end, making your tokens available to be redeemed.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-staking"
            ),

            StorySlide(
                description:
                "Staking is an important part of the network security and reliability. Anyone can run Polkadot & Kusama validator nodes, but only those who have enough tokens staked will be selected by the network to participate in composing new blocks and receive the rewards. Validators oftently do not have enough tokens by themselves, so Nominators are helping them by locking their tokens for them to achieve the required amount of stake.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-staking"
            )
        ]

        let slides2 = [
            StorySlide(
                description: "Nominators are those who want to earn passive income by locking their tokens for securing the network. To achieve that, Nominators should select a number of Validators to support. Nominators should be careful - if selected Validators won’t behave properly, slashing penalties would be applied to both Validators and Nominators, based on severity of incident.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-nominator"
            ),
            StorySlide(
                description: "Fearless Wallet provides support for Nominators by helping to select Validators. Mobile app fetches data from the blockchain and composes a list of Validators which have most profits, identity with contact info available, not slashed before and available to receive nominations. Fearless Wallet also cares about decentralization, so if one person or a company runs several validator nodes, only up to 2 nodes will be chosen from that person or a company in the recommended list.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-nominator"
            )
        ]

        let slides3 = [
            StorySlide(
                description: "Validators are those who run a blockchain node for 24/7 and require to have enough stake locked (both owned and provided by nominators) to be elected by the network. Validators should maintain their nodes to achieve the best performance and reliability, which will be rewarded. Being a validator is almost a full time job, there are companies exist which are focused to be validators on the blockchain networks.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-validator"
            ),

            StorySlide(
                description: "Everyone can be a validator and run a blockchain node, but that requires a certain level of technical skills and responsibility. Polkadot & Kusama network has a program, named Thousand Validators Programme, to provide support for beginners. The network itself always will reward more Validators who have less stake (but enough to be elected) to improve decentralization.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-validator"
            )
        ]

        let slides4 = [
            StorySlide(
                description: "Rewards for staking are available for claiming at the end of each Era (6 hours in Kusama and 24 hours in Polkadot). They are available for claiming for next 84 Eras, and in most cases Validators are paying out the rewards for everyone. However, Validators might forget or something might happen with them, so Nominators can claim the rewards by themselves.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-simple-payouts"
            ),

            StorySlide(
                description: "Although usually Rewards are distributed by Validators, Fearless Wallet helps Nominators by alerting them if there are some Rewards available and they are close to expiration. You will receive Alert about this and other activities on your Staking screen.",
                urlString: "https://wiki.polkadot.network/docs/en/learn-simple-payouts"
            )
        ]
        // swiftlint:enable line_length

        let story1 = Story(icon: "💰", title: "What is Staking?", slides: slides1)
        let story2 = Story(icon: "💎", title: "Who is a Nominator?", slides: slides2)
        let story3 = Story(icon: "⛏", title: "Who is a Validator?", slides: slides3)
        let story4 = Story(icon: "🎁", title: "Rewards", slides: slides4)

        return StoriesModel(stories: [story1, story2, story3, story4])
    }
}
