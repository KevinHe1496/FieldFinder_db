import Vapor
import JWT

struct JWTToken: JWTPayload, Authenticatable {
    var userID: SubjectClaim
    var username: SubjectClaim
    var expiration: ExpirationClaim
    var isRefresh: BoolClaim
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}


extension JWTToken {
    static func generateTokens(
        for username: String,
        andId userId: UUID
    ) -> (
        accessToken: JWTToken,
        refreshToken: JWTToken
    ) {
        let now = Date.now
        let tokenExpDate = now.addingTimeInterval(Constants.accessTokenLifetime)
        let refreshExpDate = now.addingTimeInterval(Constants.refreshTokenLifetime)
        let accessToken = JWTToken(
            userID: .init(value: userId.uuidString),
            username: .init(value: username),
            expiration: .init(value: tokenExpDate),
            isRefresh: false
        )
        let refreshToken = JWTToken(
            userID: .init(value: userId.uuidString),
            username: .init(value: username),
            expiration: .init(value: refreshExpDate),
            isRefresh: true
        )
        
        return (accessToken, refreshToken)
    }
}
