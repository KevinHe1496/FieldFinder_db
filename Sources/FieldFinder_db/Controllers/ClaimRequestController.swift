import Vapor
import Fluent

/// Controlador que gestiona el ciclo de vida de las solicitudes de reclamación de establecimientos.
///
/// ## Flujo completo
/// 1. Un usuario autenticado envía una solicitud con `POST /api/establecimiento/:id/reclamar`
///    (manejado en `EstablecimientoController`). Se crea un `ClaimRequest` con estado `pendiente`.
/// 2. Un administrador lista las solicitudes pendientes con `GET /api/claims`.
/// 3. El administrador aprueba con `POST /api/claims/:claimID/aprobar` o rechaza con
///    `POST /api/claims/:claimID/rechazar`.
/// 4. Al aprobar: el establecimiento recibe el `user_id` del reclamante y todas las demás
///    solicitudes pendientes para ese establecimiento se rechazan automáticamente.
///
/// ## Endpoints disponibles
/// | Método | Ruta                                  | Acceso  | Descripción                             |
/// |--------|---------------------------------------|---------|-----------------------------------------|
/// | GET    | /api/claims                           | Admin   | Lista todas las solicitudes             |
/// | GET    | /api/claims/pendientes                | Admin   | Lista solo las solicitudes pendientes   |
/// | POST   | /api/claims/:claimID/aprobar          | Admin   | Aprueba una solicitud                   |
/// | POST   | /api/claims/:claimID/rechazar         | Admin   | Rechaza una solicitud                   |
/// | GET    | /api/claims/mis-solicitudes           | Usuario | Ver las propias solicitudes del usuario |
struct ClaimRequestController: RouteCollection {

    func boot(routes: any RoutesBuilder) throws {
        routes.group("claims") { builder in

            let protected = builder.grouped([
                JWTToken.authenticator(),
                JWTToken.guardMiddleware()
            ])

            // Rutas solo para administradores
            let adminOnly = protected.grouped(AdminMiddleware())
            adminOnly.get(use: getAllClaims)
            adminOnly.get("pendientes", use: getPendingClaims)
            adminOnly.post(":claimID", "aprobar", use: aprobarClaim)
            adminOnly.post(":claimID", "rechazar", use: rechazarClaim)

            // Ruta para que el usuario vea sus propias solicitudes
            protected.get("mis-solicitudes", use: getMisSolicitudes)
        }
    }
}

extension ClaimRequestController {

    /// Devuelve todas las solicitudes de reclamación, sin importar su estado. Solo para admins.
    @Sendable
    func getAllClaims(req: Request) async throws -> [ClaimRequest.Public] {
        let claims = try await ClaimRequest.query(on: req.db)
            .with(\.$user)
            .with(\.$establecimiento)
            .sort(\.$createdAt, .descending)
            .all()

        return claims.map { $0.toPublic() }
    }

    /// Devuelve únicamente las solicitudes con estado `pendiente`. Solo para admins.
    @Sendable
    func getPendingClaims(req: Request) async throws -> [ClaimRequest.Public] {
        let claims = try await ClaimRequest.query(on: req.db)
            .filter(\.$status == .pendiente)
            .with(\.$user)
            .with(\.$establecimiento)
            .sort(\.$createdAt, .ascending)
            .all()

        return claims.map { $0.toPublic() }
    }

    /// Aprueba una solicitud de reclamación. Solo para admins.
    /// - Asigna el usuario como dueño del establecimiento.
    /// - Rechaza automáticamente cualquier otra solicitud pendiente para el mismo establecimiento.
    @Sendable
    func aprobarClaim(req: Request) async throws -> HTTPStatus {
        guard let claimID = req.parameters.get("claimID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de solicitud inválido.")
        }

        // 1. Cargar la solicitud con sus relaciones
        guard let claim = try await ClaimRequest.query(on: req.db)
            .filter(\.$id == claimID)
            .with(\.$establecimiento)
            .first()
        else {
            throw Abort(.notFound, reason: "Solicitud no encontrada.")
        }

        // 2. Solo se pueden aprobar solicitudes pendientes
        guard claim.status == .pendiente else {
            throw Abort(.conflict, reason: "Esta solicitud ya fue procesada (estado: \(claim.status.rawValue)).")
        }

        // 3. Verificar que el establecimiento aún no tenga dueño
        guard claim.establecimiento.$user.id == nil else {
            throw Abort(.conflict, reason: "El establecimiento ya tiene dueño. Rechaza esta solicitud manualmente.")
        }

        guard let reclamante = try await User.find(claim.$user.id, on: req.db) else {
            throw Abort(.notFound, reason: "El usuario que envió la solicitud ya no existe.")
        }

        // Todo en una transacción: o se aplica completo o no se aplica nada.
        try await req.db.transaction { db in
            // 4. Asignar el dueño al establecimiento
            claim.establecimiento.$user.id = reclamante.id
            try await claim.establecimiento.save(on: db)

            // 5. Convertir al reclamante en dueño. Sin esto, las rutas protegidas con
            //    RoleMiddleware(.dueno) (editar establecimiento, registrar canchas) le darían 403.
            if reclamante.rol != .dueno {
                reclamante.rol = .dueno
                try await reclamante.save(on: db)
            }

            // 6. Marcar esta solicitud como aprobada
            claim.status = .aprobada
            try await claim.save(on: db)

            // 7. Rechazar automáticamente todas las demás solicitudes pendientes para el mismo establecimiento
            let otrasPendientes = try await ClaimRequest.query(on: db)
                .filter(\.$establecimiento.$id == claim.$establecimiento.id)
                .filter(\.$status == .pendiente)
                .all()

            for otra in otrasPendientes {
                otra.status = .rechazada
                try await otra.save(on: db)
            }
        }

        return .ok
    }

    /// Rechaza una solicitud de reclamación. Solo para admins.
    @Sendable
    func rechazarClaim(req: Request) async throws -> HTTPStatus {
        guard let claimID = req.parameters.get("claimID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "ID de solicitud inválido.")
        }

        guard let claim = try await ClaimRequest.find(claimID, on: req.db) else {
            throw Abort(.notFound, reason: "Solicitud no encontrada.")
        }

        guard claim.status == .pendiente else {
            throw Abort(.conflict, reason: "Esta solicitud ya fue procesada (estado: \(claim.status.rawValue)).")
        }

        claim.status = .rechazada
        try await claim.save(on: req.db)

        return .ok
    }

    /// Devuelve las solicitudes de reclamación enviadas por el usuario autenticado.
    @Sendable
    func getMisSolicitudes(req: Request) async throws -> [ClaimRequest.Public] {
        let token = try req.auth.require(JWTToken.self)
        guard let userId = UUID(token.userID.value) else {
            throw Abort(.unauthorized, reason: "Token inválido.")
        }

        let claims = try await ClaimRequest.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$user)
            .with(\.$establecimiento)
            .sort(\.$createdAt, .descending)
            .all()

        return claims.map { $0.toPublic() }
    }
}
