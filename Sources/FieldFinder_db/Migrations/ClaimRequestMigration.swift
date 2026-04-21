import Fluent

/// Crea la tabla `claim_requests` en la base de datos.
/// Cada fila representa una solicitud de un usuario para reclamar la propiedad de un establecimiento.
struct ClaimRequestMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(ClaimRequest.schema)
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("establecimiento_id", .uuid, .required, .references("establecimientos", "id", onDelete: .cascade))
            .field("telefono_contacto", .string, .required)
            .field("mensaje", .string, .required)
            .field("status", .string, .required)
            .field("created_at", .date)
            .field("updated_at", .date)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ClaimRequest.schema).delete()
    }
}
