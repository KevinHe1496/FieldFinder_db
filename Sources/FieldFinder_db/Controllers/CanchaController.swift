import Vapor
import Fluent

/// Controlador encargado de manejar las rutas relacionadas con canchas, como su creación.
struct CanchaController: RouteCollection {
    
    /// Registra las rutas bajo `/cancha` y asocia el endpoint de registro de cancha.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("cancha") { builder in
            // Ruta POST /cancha/register para crear una nueva cancha
            builder.post("register", use: createCancha)
            builder.post("fotos", ":canchaID", use: uploadFotosCanchaHandler)
            builder.get(":canchaID", use: getCanchaByID)
            builder.grouped(RoleMiddleware(requiredRole: .jugador)).get("getAll", "Canchas", use: getAllCanchas)
            builder.delete("delete", ":canchaID", use: deleteCanchaByID)
            builder.put("update",":canchaID", use: updateCancha)
            builder.get("fotos", ":canchaID", use: getFotosCanchaHandler)
        }
    }
}

extension CanchaController {
    
    /// Crea una nueva cancha asociada a un establecimiento del usuario autenticado, validando propiedad y guardando la cancha.
    @Sendable
    func createCancha(req: Request) async throws -> Cancha.List {
        
        // 1. Extraer el token JWT del request (cabecera Authorization)
        let token = try req.auth.require(JWTToken.self)
        
        // 2. Obtener el ID del usuario a partir del token
        guard let userId = UUID(token.userID.value),
              let _ = try await User.find(userId, on: req.db) else {
            throw Abort(.notFound, reason: "Usuario no encontrado")
        }
        
        // 2. Decodifica el cuerpo de la solicitud con el contenido enviado
        let create = try req.content.decode(Cancha.Create.self)
        print("Input recibido:", create)
        
        // 3. Verifica que el establecimiento exista y pertenezca al usuario autenticado
        guard let establecimiento = try await Establecimiento.query(on: req.db)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.unauthorized, reason: "No puedes registrar canchas en un establecimiento que no te pertenece.")
        }
        
        // 4. Crea una nueva instancia del modelo Cancha a partir del DTO
        let cancha = create.toModel(establecimientoID: try establecimiento.requireID())
        
        // 5. Guarda la cancha en la base de datos
        try await cancha.save(on: req.db)
        
        // 6. Retonar solo el ID  de la cancha
        return cancha.toList()
    }
    
    /// Devuelve los datos de un establecimiento específico por ID, incluyendo las fotos.
    @Sendable
    func getCanchaByID(req: Request) async throws -> Cancha.Public {
        
        // 1. Intentar obtener el parámetro "canchaID" desde la URL, y convertirlo a UUID
        guard let id = req.parameters.get("canchaID", as: UUID.self) else {
            // Si no se puede obtener o convertir, lanzar un error 400 (Bad Request)
            throw Abort(.badRequest, reason: "ID inválido.")
        }
        
        // 2. Buscar en la base de datos la cancha con ese ID
        guard let cancha = try await Cancha.find(id, on: req.db) else {
            // Si no se encuentra la cancha, lanzar un error 404 (Not Found)
            throw Abort(.notFound, reason: "Cancha no encontrada.")
        }
        
        // 3. Cargar las relaciones necesarias (en este caso, las fotos asociadas a la cancha)
        try await cancha.$fotos.load(on: req.db)
        
        // 4. Convertir el modelo Cancha a su representación pública (DTO) y devolverlo como respuesta
        return cancha.toPublic()
    }
    
    /// Devuelve una lista de todas las canchas registradas, incluyendo sus fotos asociadas.
    /// - Returns: Un arreglo de canchas en su representación pública (DTO).
    @Sendable
    func getAllCanchas(req: Request) async throws -> [Cancha.Public] {
        
        // 1. Consultar todas las canchas desde la base de datos, incluyendo la relación con sus fotos
        let canchas = try await Cancha.query(on: req.db)
            .with(\.$fotos) // Relación 1-N: una cancha puede tener varias fotos
            .all()
        
        // 2. Convertir cada cancha al formato público y retornar la lista
        return canchas.map { $0.toPublic() }
    }

    /// Elimina una cancha específica por su ID si pertenece a un establecimiento del usuario autenticado.
    /// También elimina todas sus fotos asociadas.
    /// - Returns: HTTP 204 (No Content) si la eliminación fue exitosa.
    @Sendable
    func deleteCanchaByID(req: Request) async throws -> HTTPStatus {
        // 1. Validar el token y obtener el usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        // 2. Obtener el ID de la cancha desde los parámetros de la URL
        guard let canchaID = req.parameters.get("canchaID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de cancha inválido.")
        }

        // 3. Buscar la cancha por ID
        guard let cancha = try await Cancha.find(canchaID, on: req.db) else {
            throw Abort(.notFound, reason: "Cancha no encontrada.")
        }

        // 4. Cargar el establecimiento al que pertenece la cancha
        try await cancha.$establecimiento.load(on: req.db)
        
        // 5. Cargar el usuario dueño del establecimiento
        try await cancha.establecimiento.$user.load(on: req.db)

        // 6. Validar que el usuario autenticado sea el dueño del establecimiento
        guard cancha.establecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No tienes permiso para eliminar esta cancha.")
        }

        // 7. Cargar y eliminar todas las fotos asociadas a la cancha
        try await cancha.$fotos.load(on: req.db)
        for foto in cancha.fotos {
            try await foto.delete(on: req.db)
        }

        // 8. Eliminar la cancha
        try await cancha.delete(on: req.db)

        // 9. Retornar HTTP 204 (sin contenido)
        return .noContent
    }

    
    /// Actualiza una cancha existente si pertenece a un establecimiento del usuario autenticado.
    /// - Returns: La representación pública de la cancha actualizada.
    @Sendable
    func updateCancha(req: Request) async throws -> Cancha.Public {
        
        // 1. Validar el token y obtener el usuario
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        // 2. Obtener el ID de la cancha desde los parámetros
        guard let canchaID = req.parameters.get("canchaID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de la cancha inválido.")
        }

        // 3. Buscar la cancha en la base de datos
        guard let cancha = try await Cancha.find(canchaID, on: req.db) else {
            throw Abort(.notFound, reason: "Cancha no encontrada.")
        }

        // 4. Cargar el establecimiento y el usuario dueño
        try await cancha.$establecimiento.load(on: req.db)
        try await cancha.establecimiento.$user.load(on: req.db)

        // 5. Verificar que el usuario autenticado sea el dueño
        guard cancha.establecimiento.user.id == userId else {
            throw Abort(.unauthorized, reason: "No tienes permiso para modificar esta cancha.")
        }

        // 6. Decodificar los nuevos datos
        let updateData = try req.content.decode(Cancha.Update.self)

        // 7. Actualizar los campos
        cancha.tipo = updateData.tipo
        cancha.modalidad = updateData.modalidad
        cancha.precio = updateData.precio
        cancha.iluminada = updateData.iluminada
        cancha.cubierta = updateData.cubierta

        // 8. Guardar los cambios
        try await cancha.update(on: req.db)

        // 9. Recargar relaciones necesarias
        try await cancha.$fotos.load(on: req.db)

        // 10. Retornar la representación pública
        return cancha.toPublic()
    }

    @Sendable
    func uploadFotosCanchaHandler(req: Request) async throws -> HTTPStatus {
        
        // 1. Validar el token JWT del usuario autenticado
        let token = try req.auth.require(JWTToken.self)
        
        // 2. Obtener el UUID del usuario desde el token
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }
        
        // 3. Obtener el ID de la cancha desde los parámetros de la URL
        guard let canchaID = req.parameters.get("canchaID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de la cancha inválido.")
        }
        
        // 4. Buscar la cancha por su ID
        guard let cancha = try await Cancha.find(canchaID, on: req.db) else {
            throw Abort(.notFound, reason: "Cancha no encontrada.")
        }
        
        // 5. Cargar el establecimiento al que pertenece la cancha
        try await cancha.$establecimiento.load(on: req.db)
        
        // 6. Verificar que el usuario autenticado sea dueño del establecimiento de esa cancha
        guard cancha.establecimiento.$user.id == userId else {
            throw Abort(.unauthorized, reason: "No puedes subir fotos a una cancha que no te pertenece.")
        }
        
        // 7. Estructura auxiliar para recibir múltiples archivos enviados como `multipart/form-data`
        struct FileUpload: Content {
            var files: [File] // clave en el form-data: files[]
        }
        
        // 8. Decodificar los archivos recibidos desde la petición HTTP
        let data = try req.content.decode(FileUpload.self)
        
        // 9. Iterar sobre los archivos recibidos
        for file in data.files {
            // 9.1 Guardar el archivo en S3  y obtener su URL pública
            let publicURL = try await req.uploadFileToS3(file: file, folder: "cancha") // 👈 sube a S3
            
            // 9.2 Crear una instancia de `CanchaFoto` asociada a la cancha
            let foto = CanchaFoto(url: publicURL, canchaID: canchaID)
            
            // 9.3 Guardar la foto en la base de datos
            try await foto.save(on: req.db)
        }
        
        // 10. Retornar HTTP 201 Created si todo salió bien
        return .created
    }
    
    @Sendable
    func getFotosCanchaHandler(req: Request) async throws -> [String] {
        // 3. Obtener el ID de la cancha desde los parámetros de la URL
        guard let canchaID = req.parameters.get("canchaID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de la cancha inválido.")
        }
        // Verifica que la cancha exista (opcional pero recomendable)
        guard let _ = try await Cancha.find(canchaID, on: req.db) else {
            throw Abort(.notFound, reason: "Cancha no encontrado.")
        }
        // Obtiene todas las fotos relacionadas
        let fotos = try await CanchaFoto.query(on: req.db)
            .filter(\.$cancha.$id == canchaID)
            .all()
        
        // Devuelve solo los URLs
        return fotos.map { $0.url }
    }
}
