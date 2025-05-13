import Vapor
import Fluent

/// Controlador encargado de manejar la información de los usuarios, incluyendo consulta individual y listado general (solo para admins).
struct UserController: RouteCollection {
    
    /// Define las rutas bajo `/users` y aplica middlewares según el caso.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("users") { users in
            users.get("me", use: getMe)
            users.grouped(AdminMiddleware()).get(use: index)
            users.put("update", "me", use: updateMe)
            users.delete("delete", "me", use: deleteMe)
            users.group("favoritos") { favoritos in
                favoritos.get(use: getMisFavoritos)
                favoritos.post(":establecimientoID", use: marcarFavorito) // POST /users/favoritos/:id
                favoritos.delete(":establecimientoID", use: eliminarFavorito) // DELETE /users/favoritos/:id
            }
        }
    }
}

extension UserController {
    
    /// Devuelve la información pública del usuario autenticado, incluyendo sus establecimientos,
    /// fotos, canchas y relaciones asociadas. El usuario se identifica a través del token JWT.
    /// - Returns: Una instancia de `User.Public` con todos los datos cargados necesarios.
    @Sendable
    func getMe(req: Request) async throws -> User.Public {
        
        // 1. Extraer el token JWT del request (cabecera Authorization)
        let token = try req.auth.require(JWTToken.self)
        
        // 2. Obtener el ID del usuario a partir del token
        guard let userId = UUID(token.userID.value),
              let _ = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }
        
        // 3. Consultar el usuario con sus relaciones cargadas desde la base de datos:
        // - establecimientos del usuario
        // - fotos de cada establecimiento
        // - canchas de cada establecimiento, con sus fotos
        let getUser = try await User.query(on: req.db)
            .filter(\.$id == userId)  // Filtramos el usuario por su ID obtenido desde el token
            .with(\.$establecimientos) { establecimiento in
                establecimiento
                    .with(\.$fotos) // Fotos del establecimiento
                    .with(\.$user)  // Dueño del establecimiento
                    .with(\.$canchas) { cancha in
                        cancha.with(\.$fotos) // Fotos de cada cancha
                    }
            }
            .first()
        
        // 4. Verificar que se haya encontrado el usuario
        guard let currentUser = getUser else {
            throw Abort(.notFound, reason: "User not found.")
        }
        
        // 5. Devolver la representación pública del usuario
        return currentUser.toPublic()
    }
    
    
    /// Devuelve la lista completa de usuarios, con sus establecimientos, canchas, visible solo para administradores.
    @Sendable
    func index(req: Request) async throws -> [User.Public] {
        
        try await User.query(on: req.db)
            .with(\.$establecimientos) { establecimiento in
                establecimiento
                    .with(\.$fotos)
                    .with(\.$user)
                    .with(\.$canchas) { cancha in
                        cancha.with(\.$fotos)
                    }
            }
            .all().map { user in
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
    
    /// Elimina la cuenta del usuario autenticado, incluyendo todos sus establecimientos,
    /// sus canchas, y las fotos asociadas a ambos.
    /// - Returns: HTTP 204 (No Content) si se elimina correctamente.
    @Sendable
    func deleteMe(req: Request) async throws -> HTTPStatus {
        
        // 1. Validar el token JWT y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value),
              let user = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }
        
        // 2. Obtener todos los establecimientos del usuario, incluyendo:
        //    - canchas con sus fotos
        //    - fotos del establecimiento
        let establecimientos = try await user.$establecimientos.query(on: req.db)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos) // fotos de cada cancha
            }
            .with(\.$fotos) // fotos del establecimiento
            .all()
        
        // 3. Recorrer cada establecimiento y eliminar en orden: fotos, canchas y establecimiento
        for est in establecimientos {
            // 3.1 Eliminar las fotos de cada cancha
            for cancha in est.canchas {
                for foto in cancha.fotos {
                    try await foto.delete(on: req.db)
                }
                // 3.2 Eliminar la cancha después de sus fotos
                try await cancha.delete(on: req.db)
            }
            
            // 3.3 Eliminar las fotos del establecimiento
            for foto in est.fotos {
                try await foto.delete(on: req.db)
            }
            
            // 3.4 Eliminar el establecimiento
            try await est.delete(on: req.db)
        }
        
        // 4. Finalmente, eliminar el usuario
        try await user.delete(on: req.db)
        
        // 5. Retornar HTTP 204 (sin contenido) para indicar éxito
        return .noContent
    }
    
    /// Marca un establecimiento como favorito para el usuario autenticado.
    /// - Parameters: Ningún parámetro en el body. El `establecimientoID` viene en la URL.
    /// - Returns: HTTP 201 (Created) si el establecimiento fue marcado como favorito.
    @Sendable
    func marcarFavorito(req: Request) async throws -> HTTPStatus {
        // 1. Validar el token y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userID = UUID(token.userID.value),
              let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized)
        }

        // 2. Obtener el ID del establecimiento desde la URL y validarlo
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self),
              let establecimiento = try await Establecimiento.find(establecimientoID, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado")
        }

        // 3. Asociar el establecimiento al usuario como favorito
        try await user.$favoritos.attach(establecimiento, on: req.db)

        // 4. Retornar HTTP 201 (Created)
        return .created
    }


    /// Elimina un establecimiento de los favoritos del usuario autenticado.
    /// - Parameters: Ningún parámetro en el body. El `establecimientoID` viene en la URL.
    /// - Returns: HTTP 204 (No Content) si se elimina correctamente.
    @Sendable
    func eliminarFavorito(req: Request) async throws -> HTTPStatus {
        // 1. Validar el token y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userID = UUID(token.userID.value),
              let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized)
        }

        // 2. Obtener el ID del establecimiento desde la URL y validarlo
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self),
              let establecimiento = try await Establecimiento.find(establecimientoID, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado")
        }

        // 3. Eliminar la relación de favorito entre el usuario y el establecimiento
        try await user.$favoritos.detach(establecimiento, on: req.db)
        

        // 4. Retornar HTTP 204 (No Content)
        return .noContent
    }


    /// Devuelve todos los establecimientos marcados como favoritos por el usuario autenticado.
    /// - Returns: Un array de `Establecimiento.FavoriteDTO` con los favoritos del usuario.
    @Sendable
    func getMisFavoritos(req: Request) async throws -> [Establecimiento.FavoriteDTO] {
        // 1. Validar el token y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userID = UUID(token.userID.value),
              let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized)
        }

        // 2. Consultar los establecimientos favoritos del usuario y cargar sus fotos
        let favoritos = try await user.$favoritos.query(on: req.db)
            .with(\.$fotos)
            .all()
        let favoritosIds = Set(favoritos.compactMap { $0.id })

        // 3. Convertir cada establecimiento a su DTO de favorito y devolverlos
        return favoritos.map { $0.toFavoriteDTO(isFavorite: favoritosIds.contains($0.id!))}
    }

}
