import Fluent
import FluentPostgresDriver

/// En producción la tabla `establecimientos` se creó cuando `user_id` era obligatorio.
/// Desde el flujo de reclamos, un establecimiento puede existir sin dueño (lo crea un admin
/// o el seed de Google Places y el dueño lo reclama después), así que `user_id` debe aceptar NULL.
/// La migración original ya no lo marca como requerido, pero eso no cambia una tabla que ya existe.
struct EstablecimientoUserIDOptionalMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE establecimientos ALTER COLUMN user_id DROP NOT NULL").run()
    }

    func revert(on database: any Database) async throws {
        guard let sql = database as? any SQLDatabase else { return }
        try await sql.raw("ALTER TABLE establecimientos ALTER COLUMN user_id SET NOT NULL").run()
    }
}
