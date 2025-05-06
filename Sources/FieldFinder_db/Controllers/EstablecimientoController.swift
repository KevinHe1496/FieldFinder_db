import Vapor
import Fluent

/// Controlador encargado de gestionar los establecimientos: registro, obtención y eliminación.
struct EstablecimientoController: RouteCollection {
    
    /// Define las rutas bajo `/establecimiento` y las asocia con middlewares y funciones.
    func boot(routes: any RoutesBuilder) throws {
        routes.group("establecimiento") { builder in
            // Ruta protegida: solo dueños pueden registrar establecimientos
            builder.grouped(RoleMiddleware(requiredRole: .dueno)).post("register", use: crearEstablecimiento)
            
            // Ruta protegida: solo admins pueden ver todos los establecimientos
            builder.grouped(AdminMiddleware()).get("getEstablecimientos", use: getAllEstablisments)
            
            // Ruta pública: obtener establecimiento por ID
            builder.get(":establecimientoID", use: getEstablecimientoByID)
            builder.delete(":establecimientoID", use: deleteEstablecimientoByID)
        }
    }
}

extension EstablecimientoController {
    
    /// Registra un nuevo establecimiento para el usuario autenticado con rol dueño.
    @Sendable
    func crearEstablecimiento(req: Request) async throws -> HTTPStatus {
        do {
            // 1. Validar y extraer el token del usuario autenticado
            let token = try req.auth.require(JWTToken.self)
            guard let userID = UUID(token.userID.value) else {
                throw Abort(.unauthorized, reason: "Token inválido")
            }

            // 2. Decodificar los datos enviados en la petición
            let create = try req.content.decode(Establecimiento.Create.self)
            print("Input recibido:", create)

            // 3. Crear y guardar el establecimiento con el userID del token
            let establecimiento = create.toModel(userId: userID)
            try await establecimiento.save(on: req.db)

            // 4. Devolver respuesta HTTP 201 Created
            return .created
        } catch {
            print("Error al crear el establecimiento: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "No se pudo crear el establecimiento.")
        }
    }

    /// Devuelve todos los establecimientos con sus canchas y el usuario asociado (solo para admins).
    @Sendable
    func getAllEstablisments(req: Request) async throws -> [Establecimiento.Public] {
        let establecimientos = try await Establecimiento.query(on: req.db)
            .with(\.$canchas) // Relación 1-N con canchas
            .with(\.$user)    // Relación con usuario creador
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

}
