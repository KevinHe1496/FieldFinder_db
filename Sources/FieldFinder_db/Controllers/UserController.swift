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
            
            users.put("update", "me", use: updateMe)
            
            users.delete("delete", "me", use: deleteMe)
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
    
    /// Actualiza la información del usuario autenticado (nombre, rol, contraseña).
    @Sendable
    func updateMe(req: Request) async throws -> User.Public {
        // 1. Validar token y obtener usuario
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value),
              let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }

        // 2. Validar y decodificar contenido
        try User.Update.validate(content: req)
        let updateData = try req.content.decode(User.Update.self)

        // 3. Actualizar los campos
        user.name = updateData.name
        user.password = try Bcrypt.hash(updateData.password)

        // 4. Guardar
        try await user.save(on: req.db)

        // 5. Devolver info pública
        return user.toPublic()
    }
    
    /// Elimina la cuenta del usuario autenticado.
    /// - Returns: HTTP 204 si se elimina correctamente.
    @Sendable
    func deleteMe(req: Request) async throws -> HTTPStatus {
        // 1. Obtener el token y validar el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value),
              let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }


        // 2. Eliminar el usuario
        try await user.delete(on: req.db)

        // 3. Retornar respuesta sin contenido
        return .noContent
    }


}
