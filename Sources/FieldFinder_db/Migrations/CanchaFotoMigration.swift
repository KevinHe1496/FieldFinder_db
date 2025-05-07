import Fluent

struct CanchaFotoMigration: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(CanchaFoto.schema)
            .id()
            .field("url", .string, .required)
            .field("cancha_id", .uuid, .required, .references("canchas", "id", onDelete: .cascade))
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(CanchaFoto.schema).delete()
    }
}

