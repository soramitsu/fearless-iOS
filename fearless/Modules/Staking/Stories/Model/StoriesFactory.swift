import Foundation

protocol StoriesFactoryProtocol {
    static func createModel() -> StoriesModel
}

final class StoriesFactory { }

extension StoriesFactory: StoriesFactoryProtocol {
    static func createModel() -> StoriesModel {

        // swiftlint:disable line_length
        let slides1 = [
            Slide(description: "Staking refers to the process of a Proof-of-Stake (PoS) token-holder locking a tokens in order to participate in the upkeep of the PoS network (e.g. validating transactions; composing new blocks). This increases the security and reliability of the network and is an alternative to mining in Proof-of-Work systems (e.g. Bitcoin). Token-holders who participate in staking are compensated through block rewards and transaction fees.",
                  urlString: "https://unsplash.com/s/photos/arctic"),

            Slide(description:
                   "On August, I spent about two weeks in Iceland and Greenland. This glacier was the first astonishment as we arrived in Iceland. The first time in my life sitting so close to the glacier and touch the cold water. Not just cold but extremely freezing. Still, an unbelievably beautiful scenery with no doubt.",
                  urlString: "https://unsplash.com/s/photos/arctic")
        ]

        let slides2 = [
            Slide(description: "Iceland ",
                  urlString: "https://unsplash.com/s/photos/arctic")
        ]

        let slides3 = [
            Slide(description: "A hiker with his dog. On top of Untersberg in Salzburg, Austria.",
                  urlString: "https://unsplash.com/s/photos/arctic"),

            Slide(description: "White Sands National Monument in New Mexico, USA has been on my wishlist for years. Seeing photographers take some of the most stunning images I have ever seen, I knew when I had the chance I had to visit.",
                  urlString: "https://unsplash.com/s/photos/arctic")
        ]

        let slides4 = [
            Slide(description: "Aerial (drone) view of Arctic Icebergs",
                  urlString: "https://unsplash.com/s/photos/arctic")
        ]
        // swiftlint:enable line_length

        let story1 = Story(icon: "💰", title: "What is Staking?", slides: slides1)
        let story2 = Story(icon: "💎", title: "Who is Nominator?", slides: slides2)
        let story3 = Story(icon: "⛏", title: "Who is Validator?", slides: slides3)
        let story4 = Story(icon: "🎁", title: "What is Staking 2?", slides: slides4)

        return StoriesModel(stories: [story1, story2, story3, story4])
    }
}
