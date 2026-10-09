import Vapor
import Fluent

/// Lógica para aprobar o rechazar solicitudes de reclamo.
/// La usan tanto las rutas de admin (`/api/claims/...`) como los comandos de terminal.
enum ClaimReview {

    /// Aprueba una solicitud pendiente:
    /// - asigna al reclamante como dueño del establecimiento,
    /// - le cambia el rol a `dueno`,
    /// - rechaza las demás solicitudes pendientes del mismo establecimiento.
    /// Devuelve la solicitud aprobada con `user` y `establecimiento` cargados.
    @discardableResult
    static func approve(claimID: UUID, on database: any Database) async throws -> ClaimRequest {
        guard let claim = try await ClaimRequest.query(on: database)
            .filter(\.$id == claimID)
            .with(\.$establecimiento)
            .with(\.$user)
            .first()
        else {
            throw Abort(.notFound, reason: "Solicitud no encontrada.")
        }

        guard claim.status == .pendiente else {
            throw Abort(.conflict, reason: "Esta solicitud ya fue procesada (estado: \(claim.status.rawValue)).")
        }

        guard claim.establecimiento.$user.id == nil else {
            throw Abort(.conflict, reason: "El establecimiento ya tiene dueño. Rechaza esta solicitud.")
        }

        let reclamante = claim.user

        // Todo en una transacción: o se aplica completo o no se aplica nada.
        try await database.transaction { db in
            claim.establecimiento.$user.id = try reclamante.requireID()
            try await claim.establecimiento.save(on: db)

            // Sin esto, las rutas con RoleMiddleware(.dueno) (editar establecimiento,
            // registrar canchas) le darían 403.
            if reclamante.rol != .dueno {
                reclamante.rol = .dueno
                try await reclamante.save(on: db)
            }

            claim.status = .aprobada
            try await claim.save(on: db)

            let otrasPendientes = try await ClaimRequest.query(on: db)
                .filter(\.$establecimiento.$id == claim.$establecimiento.id)
                .filter(\.$status == .pendiente)
                .all()

            for otra in otrasPendientes {
                otra.status = .rechazada
                try await otra.save(on: db)
            }
        }

        return claim
    }

    /// Rechaza una solicitud pendiente.
    @discardableResult
    static func reject(claimID: UUID, on database: any Database) async throws -> ClaimRequest {
        guard let claim = try await ClaimRequest.query(on: database)
            .filter(\.$id == claimID)
            .with(\.$establecimiento)
            .with(\.$user)
            .first()
        else {
            throw Abort(.notFound, reason: "Solicitud no encontrada.")
        }

        guard claim.status == .pendiente else {
            throw Abort(.conflict, reason: "Esta solicitud ya fue procesada (estado: \(claim.status.rawValue)).")
        }

        claim.status = .rechazada
        try await claim.save(on: database)
        return claim
    }
}
