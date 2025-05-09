import Vapor

/// Controlador encargado de manejar la información de los usuarios, incluyendo consulta individual y listado general (solo para admins).
struct UserController: RouteCollection {
    
    /// Define las rutas bajo `/users` y aplica middlewares según el caso.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("users") { users in
            // Ruta GET /users/:id → obtener el usuario autenticado mediante token
            users.get("me", use: getMe)
            
            // Ruta GET /users → lista de todos los usuarios (solo para admins)
            users.grouped(AdminMiddleware()).get(use: index)
        }
    }
}

extension UserController {
    
    /// Devuelve la información pública del usuario autenticado (basado en el token JWT).
    @Sendable
    func getMe(req: Request) async throws -> User.Public {
        // Extraemos el token JWT del request
        let token = try req.auth.require(JWTToken.self)

        // Obtenemos el usuario desde la base de datos usando el ID del token
        guard let userId = UUID(token.userID.value),
              let myUser = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }

        // Devolvemos la información de user pública
        return myUser.toPublic()
    }
    
    /// Devuelve la lista completa de usuarios, visible solo para administradores.
    @Sendable
    func index(req: Request) async throws -> [User.Public] {
        try await User.query(on: req.db).all().map { user in
            user.toPublic()
        }
    }
}
