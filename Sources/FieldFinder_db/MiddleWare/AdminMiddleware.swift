import Vapor

/// Middleware que restringe el acceso únicamente a usuarios con permisos de administrador (`isAdmin == true`).
struct AdminMiddleware: AsyncMiddleware {
    
    /// Intercepta la solicitud y permite el acceso solo si el usuario autenticado tiene permisos de administrador.
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Extrae el token del usuario autenticado
        let token = try request.auth.require(JWTToken.self)
        
        // Busca el usuario y verifica si tiene permisos de administrador
        guard let userId = UUID(token.userID.value),
              let user = try await User.find(userId, on: request.db),
              user.isAdmin else {
            throw Abort(.unauthorized) // Rechaza la petición si no es admin
        }
        
        // Si es admin, continúa con la cadena de middlewares
        return try await next.respond(to: request)
    }
}
