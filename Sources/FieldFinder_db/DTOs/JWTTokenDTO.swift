import Vapor

extension JWTToken {
    struct Public: Content {
        let accessToken: String
        let refreshToken: String
    }
}
