import Vapor
import Fluent

struct EstablecimientoFotoMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EstablecimientoFoto.schema)
            .id()
            .field("url", .string, .required)
            .field("establecimiento_id", .uuid, .required, .references("establecimientos", "id", onDelete: .cascade))
            .create()
    }
    func revert(on database: any Database) async throws {
        try await database.schema(EstablecimientoFoto.schema).delete()
    }
}
