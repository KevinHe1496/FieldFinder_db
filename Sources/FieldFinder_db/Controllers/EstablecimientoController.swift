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
            builder.grouped(RoleMiddleware(requiredRole: .jugador)).get("getEstablecimientos", use: getAllEstablisments)
            
            // Ruta pública: obtener establecimiento por ID
            builder.get(":establecimientoID", use: getEstablecimientoByID)
            builder.delete(":establecimientoID", use: deleteEstablecimientoByID)
            builder.post(":establecimientoID", "fotos", use: uploadFotosEstablecimientoHandler)
            builder.get(":establecimientoID", "fotos", use: getFotosEstablecimientoHandler)
            builder.post("nearby", use: getNearbyEstablecimientos)
            builder.grouped(RoleMiddleware(requiredRole: .dueno)).put(":establecimientoID", use: updateEstlecimiento)
            
        }
    }
}

extension EstablecimientoController {
    
    /// Registra un nuevo establecimiento para el usuario autenticado con rol dueño.
    @Sendable
    func crearEstablecimiento(req: Request) async throws -> Establecimiento.Public {
        
        // 1. Obtener y validar el token JWT del usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userID = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido")
        }
        
        // 2. Decodificar el contenido enviado en el body de la petición (formato JSON)
        let create = try req.content.decode(Establecimiento.Create.self)
        
        // 3. Convertir los datos del formulario a un modelo de Establecimiento y asociarle el userID
        let establecimiento = create.toModel(userId: userID)
        
        // 4. Guardar el establecimiento recién creado en la base de datos
        try await establecimiento.save(on: req.db)
        
        // 5. Volver a consultar el establecimiento recién creado desde la base de datos,
        // usando el id generado automáticamente, y cargando sus relaciones (user, canchas y fotos)
        let savedEstablecimiento = try await Establecimiento.query(on: req.db)
            .filter(\.$id == establecimiento.id!) // Filtrar solo por el id del establecimiento recién guardado
            .with(\.$canchas) { cancha in         // Cargar las canchas relacionadas
                cancha.with(\.$fotos)             // Y también las fotos de cada cancha
            }
            .with(\.$user)                        // Cargar la relación con el usuario dueño
            .with(\.$fotos)                       // Cargar las fotos asociadas directamente al establecimiento
            .first()                              // Obtener el primer (y único) resultado de esa búsqueda
        
        // 6. Validar que realmente se encontró el establecimiento
        guard let fullEstablecimiento = savedEstablecimiento else {
            throw Abort(.internalServerError, reason: "No se pudo cargar el establecimiento creado.")
        }
        
        // 7. Convertir el modelo cargado a su representación pública (DTO) y retornarlo como respuesta
        return fullEstablecimiento.toPublic()
    }
    
    
    /// Devuelve todos los establecimientos con sus canchas y el usuario asociado (solo para jugadores).
    @Sendable
    func getAllEstablisments(req: Request) async throws -> [Establecimiento.Public] {
        
        let establecimientos = try await Establecimiento.query(on: req.db)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos)
            } // Relación 1-N con canchas y sus fotos
            .with(\.$user)    // Relación con usuario creador
            .with(\.$fotos) // Relacion con fotos
            .all()
        
        return establecimientos.map { $0.toPublic() }
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
        
        return establecimiento.toPublic()
    }
    
    /// Elimina un establecimiento por su ID si existe.
    @Sendable
    func deleteEstablecimientoByID(req: Request) async throws -> HTTPStatus {
        // 1. Validar que el token JWT esté presente
        let token = try req.auth.require(JWTToken.self)
        
        // 2. Obtener el UUID del usuario desde el token
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }
        
        // 3. Obtener el ID del establecimiento desde los parámetros
        guard let id = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID inválido.")
        }
        
        // 4. Buscar el establecimiento en la base de datos
        guard let establecimiento = try await Establecimiento.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }
        
        // 5. Verificar que el establecimiento pertenece al usuario autenticado
        try await establecimiento.$user.load(on: req.db)
        guard establecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes eliminar un establecimiento que no te pertenece.")
        }
        
        // 6. Eliminar el establecimiento
        try await establecimiento.delete(on: req.db)
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
        
        //Decodificamos la localización del jugador desde el JSON
        let location = try req.content.decode(LocationDTO.self)
        
        //Obtenemos todos los establecimientos
        let allEstablishments = try await Establecimiento.query(on: req.db).all()
        
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
        return nearbyEstablishments.map { $0.toPublic() }
    }
    
    /// Actualiza un establecimiento existente si pertenece al usuario autenticado.
    @Sendable
    func updateEstlecimiento(req: Request) async throws -> Establecimiento.Public {
        // 1. Validar el token y obtener el usuario
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }
        
        // 2. Obtener el ID del establecimiento desde la URL
        guard let establecimientoID = req.parameters.get("establecimientoID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID del establecimiento inválido.")
        }
        
        // 3. Buscar el establecimiento en la base de datos por el ID
        guard let establecimiento = try await Establecimiento.find(establecimientoID, on: req.db) else {
            throw Abort(.notFound, reason: "Establecimiento no encontrado.")
        }
        
        // 4. Verificar que el establecimiento pertenece al usuario
        try await establecimiento.$user.load(on: req.db)
        guard establecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes modificar un establecimiento que no te pertenece.")
        }
        
        // 5. Decodificar el nuevo contenido (formato JSON)
        let updateData = try req.content.decode(Establecimiento.Create.self)
        
        // 6. Actualizar los campos del modelo
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
        
        // 7. Guardar los cambios en la base de datos
        try await establecimiento.update(on: req.db)
        
        // 8. Obtenemos nuestro establecimiento actualizado con todas sus relaciones
        let getEstablecimiento = try await Establecimiento.query(on: req.db)
            .filter(\.$id == establecimiento.id!)
            .with(\.$canchas) { cancha in
                cancha.with(\.$fotos)
            }
            .with(\.$user)
            .with(\.$fotos)
            .first()
        
        // 9. Verificamos si se cargo el establecimiento
        guard let fullEstablecimiento = getEstablecimiento else {
            throw Abort(.internalServerError, reason: "No se pudo cargar el establecimiento.")
        }
        
        // 10. Retornar el establecimiento actualizado en formato público
        return fullEstablecimiento.toPublic()
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
