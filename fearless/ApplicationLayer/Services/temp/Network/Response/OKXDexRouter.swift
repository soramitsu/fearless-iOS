import Foundation

struct OKXDexRouter: Decodable {
    let router: String
    let routerPercent: String
    let subRouterList: [OKXDexSubrouter]
}
