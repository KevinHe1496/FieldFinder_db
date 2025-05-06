import Vapor

/// Middleware que restringe el acceso según el rol específico del usuario (por ejemplo: `.dueno` o `.jugador`).
struct RoleMiddleware: AsyncMiddleware {
    
    /// Rol requerido para poder acceder a la ruta protegida.
    let requiredRole: RolUsuario
    
    /// Valida que el usuario autenticado tenga el rol adecuado para continuar la solicitud.
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Extrae el token JWT desde el request
        let token = try request.auth.require(JWTToken.self)
        
        // Verifica que el usuario exista y que tenga el rol requerido
        guard let userId = UUID(uuidString: token.userID.value),
              let user = try await User.find(userId, on: request.db),
              user.rol == requiredRole else {
            // Si no tiene el rol requerido, lanza error 403 Forbidden
            throw Abort(.forbidden, reason: "Acceso denegado para el rol: \(requiredRole.rawValue)")
        }

        // Si todo está bien, continúa con la cadena de middlewares
        return try await next.respond(to: request)
    }
}
