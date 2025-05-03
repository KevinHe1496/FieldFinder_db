import Vapor

struct RoleMiddleware: AsyncMiddleware {
    
    let requiredRole: RolUsuario
    
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let token = try request.auth.require(JWTToken.self)
        
        guard let userId = UUID(uuidString: token.userID.value), // ✅ Usar `uuidString:` aquí
              let user = try await User.find(userId, on: request.db),
              user.rol == requiredRole else {
            throw Abort(.forbidden, reason: "Acceso denegado para el rol: \(requiredRole.rawValue)")
        }
        return try await next.respond(to: request)
    }
}
