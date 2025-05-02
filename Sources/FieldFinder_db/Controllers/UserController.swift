import Vapor

struct UserController: RouteCollection {
    // Rutas
    func boot(routes: any RoutesBuilder) throws {
        routes.group("users") { users in
            users.get("me", use: getMe)
            
            users.grouped(AdminMiddleware()).get(use: index)
        }
    }
}

extension UserController {
    @Sendable
    func getMe(req: Request) async throws -> User.Public {
        let token = try req.auth.require(JWTToken.self)
        
        guard let userId = UUID(token.userID.value),
            let myUser = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }
        return myUser.toPublic()
    }
    
    @Sendable
    func index(req: Request) async throws -> [User.Public] {
        try await User.query(on: req.db).all().map { user in
            user.toPublic()
        }
    }
}
