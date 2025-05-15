import Vapor
import Fluent

/// Controlador encargado de gestionar los establecimientos: registro, obtención y eliminación.
struct EstablecimientoController: RouteCollection {
    
    /// Define las rutas bajo `/establecimiento` y las asocia con middlewares y funciones.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("establecimiento") { builder in
            // Ruta protegida: solo dueños pueden registrar establecimientos
            builder.grouped(RoleMiddleware(requiredRole: .dueno)).post("register", use: crearEstablecimiento)
            
            // Ruta protegida: solo jugadores pueden ver todos los establecimientos
            builder.grouped(RoleMiddleware(requiredRole: .jugador)).post("getAll", "favoritos", use: getFavoritesEstablisments)
            
            // Ruta pública: obtener establecimiento por ID
            builder.get(":establecimientoID", use: getEstablecimientoByID)
            builder.delete( ":establecimientoID", use: deleteEstablecimientoByID)
            builder.post("fotos", ":establecimientoID", use: uploadFotosEstablecimientoHandler)
            builder.get("fotos", ":establecimientoID", use: getFotosEstablecimientoHandler)
            builder.post("nearby", use: getNearbyEstablecimientos)
            builder.grouped(RoleMiddleware(requiredRole: .dueno)).put(":establecimientoID", use: updateEstlecimiento)
            
        }
    }
}

extension EstablecimientoController {
    
    /// Registra un nuevo establecimiento para el usuario autenticado con rol dueño.
    @Sendable
    func crearEstablecimiento(req: Request) async throws ->  Establecimiento.List{
        
        // 1. Extraer el token JWT del request (cabecera Authorization)
        let token = try req.auth.require(JWTToken.self)
        
        // 2. Obtener el ID del usuario a partir del token
        guard let userId = UUID(token.userID.value),
              let _ = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }
   
        // 2. Decodificar el contenido enviado en el body de la petición (formato JSON)
        let create = try req.content.decode(Establecimiento.Create.self)
        
        // 3. Convertir los datos del formulario a un modelo de Establecimiento y asociarle el userID
        let establecimiento = create.toModel(userId: userId)
        
        // 4. Guardar el establecimiento recién creado en la base de datos
        try await establecimiento.save(on: req.db)

        // 7. Retornamos establecimiento con su ID
        return establecimiento.toList()
    }
    
    
    /// Devuelve todos los establecimientos con sus canchas y el usuario asociado (solo para jugadores).
    @Sendable
    func getFavoritesEstablisments(req: Request) async throws -> [Establecimiento.FavoriteDTO] {
        // 1. Validar el token JWT y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value),
              let user = try await User.find(userId, on: req.db) else {
            throw Abort(.unauthorized)
        }

        // 2. Decodificar la ubicación del jugador desde el JSON
        let location = try req.content.decode(LocationDTO.self)

        // 3. Consultar todos los establecimientos con sus fotos
        let allEstablishments = try await Establecimiento.query(on: req.db)
            .with(\.$fotos)
            .all()

        // 4. Obtener los favoritos del usuario
        let favoritos = try await user.$favoritos.query(on: req.db).all()
        let favoritosIds = Set(favoritos.compactMap { $0.id })

        // 5. Filtrar los establecimientos que están a 10 km o menos
        let filteredEstablishments = allEstablishments.filter { est in
            let distance = haversineDistance(
                lat1: location.latitude,
                lon1: location.longitude,
                lat2: est.latitude,
                lon2: est.longitude
            )
            return distance <= 10
        }

        // 6. Mapear a DTO incluyendo isFavorite
        return filteredEstablishments.map { est in
            est.toFavoriteDTO(isFavorite: favoritosIds.contains(est.id!))
        }
    }

    
    /// Devuelve los datos de un establecimiento específico por ID, incluyendo canchas y usuario.
    @Sendable
    func getEstablecimientoByID(req: Request) async throws -> Establecimiento.Public {
        guard let id = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID inválido.")
        }
        
        guard let establecimiento = try await Establecimiento.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }
        
        // Cargar relaciones necesarias antes de convertir a .Public
        try await establecimiento.$canchas.load(on: req.db)
        try await establecimiento.$user.load(on: req.db)
        try await establecimiento.$fotos.load(on: req.db)
        
        // Cargar las fotos de cada cancha relacionada
        for cancha in establecimiento.canchas {
            try await cancha.$fotos.load(on: req.db)
        }
        
        return establecimiento.toPublic()
    }
    
    /// Elimina un establecimiento por su ID, junto con sus canchas y fotos asociadas.
    /// - Returns: HTTP 204 si se elimina correctamente.
    @Sendable
    func deleteEstablecimientoByID(req: Request) async throws -> HTTPStatus {
        // 1. Validar el token JWT
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        // 2. Obtener el ID del establecimiento desde la URL
        guard let id = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID inválido.")
        }

        // 3. Buscar el establecimiento
        let establecimiento = try await Establecimiento.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$user)
            .with(\.$fotos)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos)
            }
            .first()
        
        // 4. Nos aseguramos que el establecimiento exista.
        guard let currentEstablecimiento = establecimiento else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }

        // 5. Verificar que el establecimiento pertenezca al usuario autenticado
        guard currentEstablecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes eliminar un establecimiento que no te pertenece.")
        }

        // 6. Eliminar fotos de cada cancha
        for cancha in currentEstablecimiento.canchas {
            for foto in cancha.fotos {
                try await foto.delete(on: req.db)
            }
            try await cancha.delete(on: req.db)
        }

        // 7. Eliminar fotos del establecimiento
        for foto in currentEstablecimiento.fotos {
            try await foto.delete(on: req.db)
        }

        // 8. Eliminar el establecimiento
        try await currentEstablecimiento.delete(on: req.db)

        return .noContent
    }

    
    @Sendable
    func uploadFotosEstablecimientoHandler(req: Request) async throws -> HTTPStatus {
        // 1. Validar el token y obtener el usuario
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }
        
        // 2. Obtener ID del establecimiento desde la URL
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID del establecimiento inválido.")
        }
        
        // 3. Verificar que el establecimiento exista y pertenezca al usuario
        guard let establecimiento = try await Establecimiento.find(establecimientoID, on: req.db),
              establecimiento.$user.id == userId else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado o no autorizado.")
        }
        
        // 4. Decodificar archivos recibidos
        struct FileUpload: Content {
            var files: [File]
        }
        
        let data = try req.content.decode(FileUpload.self)
        
        // 5. Guardar cada archivo usando la extensión reutilizable
        for file in data.files {
            let publicURL = try await req.uploadFileToS3(file: file, folder: "establecimiento") // 👈 sube a S3 con el nombre del folder que pongamos
            
            // 6. Crear y guardar la entidad en la BD
            let foto = EstablecimientoFoto(url: publicURL, establecimientoID: establecimientoID)
            try await foto.save(on: req.db)
        }
        
        return .created
    }
    
    
    @Sendable
    func getFotosEstablecimientoHandler(req: Request) async throws -> [String] {
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID del establecimiento inválido.")
        }
        
        // Verifica que el establecimiento exista (opcional pero recomendable)
        guard let _ = try await Establecimiento.find(establecimientoID, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }
        
        // Obtiene todas las fotos relacionadas
        let fotos = try await EstablecimientoFoto
            .query(on: req.db)
            .filter(\.$establecimiento.$id == establecimientoID)
            .all()
        
        // Devuelve solo los URLs
        return fotos.map { $0.url }
    }
    //Método para ver los establecimientos en la zona del jugador
    @Sendable
    func getNearbyEstablecimientos(req: Request) async throws -> [Establecimiento.Public] {
        // 1. Usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userID = UUID(token.userID.value),
              let user = try await User.find(userID, on: req.db) else {
            throw Abort(.unauthorized)
        }
        
        //Decodificamos la localización del jugador desde el JSON
        let location = try req.content.decode(LocationDTO.self)
        
        //Obtenemos todos los establecimientos
        let allEstablishments = try await Establecimiento.query(on: req.db)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos)
            } // Relación 1-N con canchas y sus fotos
            .with(\.$user)    // Relación con usuario creador
            .with(\.$fotos) // Relacion con fotos
            .all()
        
        // 4. Obtener favoritos del usuario
        let favoritos = try await user.$favoritos.query(on: req.db).all()
        let favoritosIDs = Set(favoritos.compactMap { $0.id })
        
        //Filtramos solo los que estan a 10km o menos usando Haversine
        let nearbyEstablishments = allEstablishments.filter { establishment in
            let distance = haversineDistance(
                lat1: location.latitude,
                lon1: location.longitude,
                lat2: establishment.latitude,
                lon2: establishment.longitude
            )
            return distance <= 10 // KM
        }
        return nearbyEstablishments.map { $0.toPublic(isFavorite: favoritosIDs.contains($0.id!)) }
    }
    
    /// Actualiza un establecimiento existente si pertenece al usuario autenticado.
    @Sendable
    func updateEstlecimiento(req: Request) async throws -> Establecimiento.Public {
        
        // 1. Validar el token JWT y obtener el ID del usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        // 2. Obtener el ID del establecimiento desde los parámetros de la URL
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID del establecimiento inválido.")
        }

        // 3. Buscar el establecimiento en la base de datos usando su ID
        guard let establecimiento = try await Establecimiento.find(establecimientoID, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }

        // 4. Verificar que el establecimiento pertenece al usuario autenticado
        try await establecimiento.$user.load(on: req.db)
        guard establecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes modificar un establecimiento que no te pertenece.")
        }

        // 5. Decodificar los nuevos datos enviados en el cuerpo de la petición
        let updateData = try req.content.decode(Establecimiento.Update.self)

        // 6. Actualizar los campos del modelo con los nuevos valores
        establecimiento.name = updateData.name
        establecimiento.info = updateData.info
        establecimiento.address = updateData.address
        establecimiento.country = updateData.country
        establecimiento.city = updateData.city
        establecimiento.zipCode = updateData.zipCode
        establecimiento.parqueadero = updateData.parqueadero
        establecimiento.vestidores = updateData.vestidores
        establecimiento.bar = updateData.bar
        establecimiento.banos = updateData.banos
        establecimiento.duchas = updateData.duchas
        establecimiento.phone = updateData.phone

        // 7. Guardar los cambios actualizados en la base de datos
        try await establecimiento.update(on: req.db)

        // 8. Volver a consultar el establecimiento actualizado, incluyendo sus relaciones
        let getEstablecimiento = try await Establecimiento.query(on: req.db)
            .filter(\.$id == establecimiento.id!)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos)
            }
            .with(\.$user)
            .with(\.$fotos)
            .first()

        // 9. Verificar que se haya podido cargar correctamente el establecimiento actualizado
        guard let updateEstablecimiento = getEstablecimiento else {
            throw Abort(.internalServerError, reason: "No se pudo cargar el establecimiento actualizado.")
        }

        // 10. Retornar la representación pública del establecimiento actualizado
        return updateEstablecimiento.toPublic()
    }
}


//MARK: Método Haversine para filtrar la distancia del consumidor con 10km de radio para recibir restaurantes
func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let earthRadius = 6371.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    
    let a = pow(sin(dLat / 2), 2)
    + cos(lat1 * .pi / 180)
    * cos(lat2 * .pi / 180)
    * pow(sin(dLon / 2), 2)
    
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earthRadius * c
}
